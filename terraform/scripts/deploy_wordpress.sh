#!/bin/bash

set -euxo pipefail  # Fail fast: exit on error, undefined variables, or pipeline failure; print each command

# Unified logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Redirect all stdout and stderr to /var/log/wordpress_install.log as well as console
exec 1> >(tee -a /var/log/wordpress_install.log) 2>&1
log "Starting WordPress installation..."

# --- 1. Install base packages needed for WordPress, minus curl/unzip (which are installed in user_data.sh.tpl) --- #

log "Installing base packages..."
apt-get update -q || { log "ERROR: apt-get update failed"; exit 1; }
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  jq \
  netcat-openbsd

# --- 2. Wait for MySQL (RDS) to become available (up to 60 seconds) --- #

log "Checking if MySQL is ready on host: ${DB_HOST}, port: ${DB_PORT}..."
for i in {1..12}; do
  if nc -z "${DB_HOST}" "${DB_PORT}"; then
    log "MySQL is reachable!"
    break
  fi
  log "MySQL not ready yet. Retrying in 5 seconds... (${i}/12)"
  sleep 5
done

# Final check after loop
if ! nc -z "${DB_HOST}" "${DB_PORT}"; then
  log "ERROR: MySQL not available after 60s. Exiting."
  exit 1
fi

# --- 3. Retrieve secrets from AWS Secrets Manager --- #

log "Retrieving secrets from AWS Secrets Manager..."
SECRETS=$(aws secretsmanager get-secret-value \
  --region "${AWS_DEFAULT_REGION}" \
  --secret-id "${SECRET_NAME}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$SECRETS" ]; then
  log "ERROR: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

log "Secrets retrieved successfully."

# Export secrets for WordPress configuration
export DB_NAME=$(echo "$SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$SECRETS" | jq -r '.DB_PASSWORD')

export WP_ADMIN=$(echo "$SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$SECRETS" | jq -r '.ADMIN_PASSWORD')

# Export WordPress security keys and salts
export AUTH_KEY=$(echo "$SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$SECRETS" | jq -r '.NONCE_SALT')

# Retrieve Redis AUTH token from AWS Secrets Manager
log "Retrieving Redis AUTH token from AWS Secrets Manager..."
REDIS_AUTH_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${AWS_DEFAULT_REGION}" \
  --secret-id "${REDIS_AUTH_SECRET_NAME}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$REDIS_AUTH_SECRETS" ]; then
  log "ERROR: Failed to retrieve Redis AUTH secret from AWS Secrets Manager"
  exit 1
fi

log "Redis AUTH secret retrieved successfully."
  
# Export Redis AUTH token for WordPress configuration
export REDIS_AUTH_TOKEN=$(echo "$REDIS_AUTH_SECRETS" | jq -r '.REDIS_AUTH_TOKEN')

# Verify all required values are present
for VAR in DB_NAME DB_USER DB_PASSWORD WP_ADMIN WP_ADMIN_EMAIL WP_ADMIN_PASSWORD \
           AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT \
           LOGGED_IN_SALT NONCE_SALT REDIS_AUTH_TOKEN; do
  if [ -z "${!VAR}" ]; then
    log "ERROR: Required secret variable $VAR is empty."
    exit 1
  fi
done

log "All secrets successfully retrieved and exported."

# --- 4. Install WordPress dependencies (Nginx, PHP, MySQL client, etc.) --- #

log "Installing WordPress dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nginx \
  php${PHP_VERSION}-fpm \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-zip \
  mysql-client \
  redis-tools

# Check if installation was successful
if [ $? -ne 0 ]; then
  log "ERROR: Failed to install WordPress dependencies."
  exit 1
fi

log "WordPress dependencies installed successfully."

# --- 5. Configure Nginx --- #

log "Configuring Nginx..."

# Ensure $WP_PATH (/var/www/html) exists before configuring Nginx
if [ ! -d "$WP_PATH" ]; then
  log "ERROR: $WP_PATH directory does not exist! Creating..."
  mkdir -p "$WP_PATH"
fi

# Detect correct PHP-FPM socket path dynamically
PHP_SOCK=$(find /run /var/run -name "php${PHP_VERSION}-fpm.sock" 2>/dev/null | head -n 1)
if [ -z "$PHP_SOCK" ]; then
    log "ERROR: PHP-FPM socket not found!"
    exit 1
fi

# Restart PHP-FPM to ensure it's running and the socket is active
log "Restarting PHP-FPM..."
systemctl restart php${PHP_VERSION}-fpm

# Ensure PHP-FPM is running
systemctl is-active php${PHP_VERSION}-fpm || { log "ERROR: PHP-FPM is not running!"; exit 1; }

# Configure Nginx virtual host for WordPress
cat <<EOL > /etc/nginx/sites-available/wordpress
server {
    listen 80;
    listen [::]:80;

    root $WP_PATH;
    index index.php index.html index.htm;

    server_name _;

    # ALB Support (Handle real client IPs)
    set_real_ip_from 0.0.0.0/0;
    real_ip_header X-Forwarded-For;

    # Support HTTPS redirection when behind ALB
    set \$forwarded_https off;
    if (\$http_x_forwarded_proto = "https") {
        set \$forwarded_https on;
    }

    # Main location block to serve WordPress
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # PHP processing block
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param HTTPS \$forwarded_https;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    # Deny access to .htaccess and other hidden files
    location ~ /\.ht {
        deny all;
    }
}
EOL

# Enable the WordPress site configuration and disable the default Nginx site
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Restart Nginx to apply the new configuration
log "Restarting Nginx..."
systemctl restart nginx

# Optimizations for scalability (Auto Scaling group)
log "Adjusting Nginx for high load and Auto Scaling..."

# Optimize Nginx for Auto Scaling (safe edit inside events block)
sed -i 's/^\s*worker_connections\s\+[0-9]\+;/    worker_connections 1024;/' /etc/nginx/nginx.conf
sed -i 's/worker_processes .*/worker_processes auto;/' /etc/nginx/nginx.conf

# Restart Nginx to apply the new configuration
log "Restarting Nginx to apply new configuration..."
systemctl restart nginx

# --- 6. Download and install WordPress --- #

log "Downloading and installing WordPress from GitHub..."

# Remove any previous WordPress installation (if files exist)
log "Removing old WordPress installation if files exist..."
if [ "$(ls -A $WP_PATH)" ]; then
  log "Removing old WordPress files..."
  rm -rf "$WP_PATH"/* # Remove all files if they exist
fi

# Define the branch, tag, or commit to clone
GIT_COMMIT="master" # Replace with a specific commit or tag if needed

# Clone the WordPress repository directly into /var/www/html (NOT into subfolder /wordpress)
git clone --depth=1 --branch "$GIT_COMMIT" https://github.com/hetmanskyi-cloud/wordpress.git $WP_PATH || {
  log "ERROR: Failed to clone WordPress repository!"
  exit 1
}

# Verify the clone was successful
if [ ! -f "$WP_PATH/wp-config-sample.php" ]; then
  log "ERROR: WordPress clone failed or incomplete!"
  exit 1
fi

# Set correct ownership and permissions
log "Setting ownership and permissions..."
chown -R www-data:www-data $WP_PATH
find $WP_PATH -type d -exec chmod 755 {} \;
find $WP_PATH -type f -exec chmod 644 {} \;

log "WordPress installation completed successfully!"

# --- 7. Install WP-CLI --- #

log "Installing WP-CLI..."

# Define WP_CLI path in temporary directory
export WP_CLI_PHAR_PATH="${WP_TMP_DIR}/wp-cli.phar"

# Ensure WP-CLI cache directory is writable by www-data
mkdir -p "${WP_TMP_DIR}/.wp-cli/cache"
chown -R www-data:www-data "${WP_TMP_DIR}/.wp-cli"
chmod -R 755 "${WP_TMP_DIR}/.wp-cli"

# Download WP-CLI to temporary directory
curl -o "$WP_CLI_PHAR_PATH" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Verify WP-CLI download
if ! php "$WP_CLI_PHAR_PATH" --info > /dev/null 2>&1; then
  log "ERROR: WP-CLI download failed or is corrupted!"
  exit 1
fi

# Make WP-CLI executable
chmod +x "$WP_CLI_PHAR_PATH"

# WP-CLI Cache Setup
mkdir -p "${WP_TMP_DIR}/wp-cli-cache"
export WP_CLI_CACHE_DIR="${WP_TMP_DIR}/wp-cli-cache"

log "WP-CLI downloaded and made executable at ${WP_CLI_PHAR_PATH}."

# --- 8. Configure wp-config.php for RDS Database (MySQL), ALB, and ElastiCache (Redis) --- #

log "Configuring wp-config.php for WordPress..."

# Ensure wp-config-sample.php exists; if missing, download it
if [ ! -f "$WP_PATH/wp-config-sample.php" ]; then
  log "WARNING: wp-config-sample.php not found! Downloading..."
  curl -o "$WP_PATH/wp-config-sample.php" https://raw.githubusercontent.com/WordPress/WordPress/master/wp-config-sample.php
fi

# Check if necessary environment variables are set
for VAR in DB_NAME DB_USER DB_PASSWORD DB_HOST DB_PORT \
           AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY \
           AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT \
           AWS_LB_DNS REDIS_HOST REDIS_PORT REDIS_AUTH_TOKEN; do
  if [ -z "${!VAR}" ]; then
    log "ERROR: Missing required environment variable $VAR!"
    exit 1
  fi
done

# Generate wp-config.php as www-data
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config create \
  --path="$WP_PATH" \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --dbhost="$DB_HOST" \
  --dbprefix="wp_" \
  --skip-check \
  --force

# Insert security keys
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set AUTH_KEY "$AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set SECURE_AUTH_KEY "$SECURE_AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set LOGGED_IN_KEY "$LOGGED_IN_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set NONCE_KEY "$NONCE_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set AUTH_SALT "$AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set SECURE_AUTH_SALT "$SECURE_AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set LOGGED_IN_SALT "$LOGGED_IN_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set NONCE_SALT "$NONCE_SALT" --path="$WP_PATH"

# Configure Redis object cache
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_HOST "$REDIS_HOST" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_PORT "$REDIS_PORT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_PASSWORD "$REDIS_AUTH_TOKEN" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_CLIENT "predis" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_SCHEME "tls" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_CACHE "true" --raw --path="$WP_PATH"

# Set site URLs from ALB DNS
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_SITEURL "http://$AWS_LB_DNS" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_HOME "http://$AWS_LB_DNS" --path="$WP_PATH"

# Verify wp-config.php was created
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  log "ERROR: wp-config.php creation failed!"
  exit 1
fi

# Set ownership and permissions
sudo chown www-data:www-data "$WP_PATH/wp-config.php"
sudo chmod 644 "$WP_PATH/wp-config.php"
log "Ownership and permissions set for wp-config.php"

# Verify DB connection over SSL
if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
    --ssl-ca="${WP_TMP_DIR}/rds-combined-ca-bundle.pem" \
    -e "USE $DB_NAME;" > /dev/null 2>&1; then
  log "Database SSL connection successful via CLI."
else
  log "ERROR: Unable to connect to the database with SSL."
  exit 1
fi

log "wp-config.php created and validated successfully."

# --- 9. Initialize WordPress database and admin user --- #

log "Starting WordPress database initialization..."
SSL_CA_PATH="${WP_TMP_DIR}/rds-combined-ca-bundle.pem"

# Print certificate path and DB connection variables
log "Using SSL_CA_PATH: $SSL_CA_PATH"
log "DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_USER=$DB_USER DB_NAME=$DB_NAME"

# Test database SSL connection using PHP (mysqli)
php -r "
\$mysqli = mysqli_init();
\$mysqli->ssl_set(null, null, '${SSL_CA_PATH}', null, null);
\$mysqli->real_connect(
    getenv('DB_HOST'),
    getenv('DB_USER'),
    getenv('DB_PASSWORD'),
    getenv('DB_NAME'),
    (int)getenv('DB_PORT'),
    null,
    MYSQLI_CLIENT_SSL
);
if (\$mysqli->connect_errno) {
    echo 'PHP SSL connection failed: (' . \$mysqli->connect_errno . ') ' . \$mysqli->connect_error . PHP_EOL;
    exit(1);
}
echo 'PHP SSL connection successful via mysqli!' . PHP_EOL;
"

# Add SSL-related constants to wp-config.php
log "Adding SSL configuration to wp-config.php..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set MYSQL_CLIENT_FLAGS MYSQLI_CLIENT_SSL --raw --path="$WP_PATH" || {
  log "ERROR: Failed to set MYSQL_CLIENT_FLAGS"
  exit 1
}

sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set MYSQL_SSL_CA "$SSL_CA_PATH" --path="$WP_PATH" || {
  log "ERROR: Failed to set MYSQL_SSL_CA"
  exit 1
}

# Validate SSL constants were added to wp-config.php
grep -E 'MYSQL_CLIENT_FLAGS|MYSQL_SSL_CA' "$WP_PATH/wp-config.php" || {
  log "WARNING: SSL configuration not found in wp-config.php!"
}

# Check if WordPress is already installed
if sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" core is-installed --path="$WP_PATH"; then
  log "WordPress is already installed. Skipping core installation."
else
  log "WordPress not installed. Proceeding with core installation..."

  # Run WordPress installation
  sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" core install \
    --path="$WP_PATH" \
    --url="http://$AWS_LB_DNS" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email || {
      log "ERROR: wp core install failed"
      exit 1
    }

  # Confirm successful installation
  if sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" core is-installed --path="$WP_PATH"; then
    log "WordPress initialization completed successfully!"
  else
    log "ERROR: WordPress initialization failed!"
    exit 1
  fi
fi

# --- 10. Install common WordPress plugins --- #

log "Installing common WordPress plugins..."

# Ensure WordPress is installed before proceeding
if ! sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" core is-installed --path="$WP_PATH"; then
  log "ERROR: WordPress is not installed. Cannot proceed with plugin installation."
  exit 1
fi

# List of plugins to install
PLUGINS=("wp-super-cache" "wordfence")

# Install and activate each plugin
for PLUGIN in "${PLUGINS[@]}"; do
  log "Installing plugin: $PLUGIN"
  if sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" plugin install "$PLUGIN" --activate --path="$WP_PATH"; then
    log "Plugin $PLUGIN installed and activated successfully."
  else
    log "ERROR: Failed to install or activate plugin: $PLUGIN"
    exit 1
  fi
done

log "All common WordPress plugins installed and activated successfully!"

# --- 11. Configure and enable Redis Object Cache --- #

log "Setting up Redis Object Cache..."

# Log Redis host and port
log "Using Redis at ${REDIS_HOST}:${REDIS_PORT}"

# Check if Redis server is reachable (non-blocking)
if ! nc -z "$REDIS_HOST" "$REDIS_PORT"; then
  log "WARNING: Redis server is not reachable at ${REDIS_HOST}:${REDIS_PORT}"
fi

# Install and activate Redis Object Cache plugin
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" plugin install redis-cache --activate --path="$WP_PATH"

# Enable Redis caching
if ! sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" redis enable --path="$WP_PATH"; then
  log "WARNING: Failed to enable Redis caching."
else
  log "Redis caching enabled successfully."
fi

# Optional: Check Redis connection status
REDIS_STATUS=$(sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" redis status --path="$WP_PATH" | grep -i "Status: Connected" || true)

if [ -n "$REDIS_STATUS" ]; then
  log "Redis is connected successfully."
else
  log "WARNING: Redis is not connected properly."
fi

# --- 12. Create ALB health check endpoint using provided content --- #

%{ if enable_s3_script }
log "Downloading healthcheck file from S3: ${healthcheck_s3_path}"
aws s3 cp "${healthcheck_s3_path}" "$WP_PATH/healthcheck.php" --region "${AWS_DEFAULT_REGION}"
if [ $? -ne 0 ]; then
  log "ERROR: Failed to download healthcheck.php from S3"
  exit 1
else
  log "ALB health check endpoint created successfully from S3"
fi
%{ else }
log "Writing embedded healthcheck content..."
echo "${healthcheck_content_b64}" | base64 --decode > "$WP_PATH/healthcheck.php"
log "ALB health check endpoint created successfully from embedded content"
%{ endif }

# Set ownership and permissions for the healthcheck file
sudo chown www-data:www-data "$WP_PATH/healthcheck.php"
sudo chmod 644 "$WP_PATH/healthcheck.php"

# --- 13. Safe system update and cleanup --- #

log "Performing safe system update..."

DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --only-upgrade
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends

# Remove unnecessary packages and clean cache
apt-get autoremove -y --purge
apt-get clean

# Move WP-CLI to permanent location
sudo mv "$WP_CLI_PHAR_PATH" /usr/local/bin/wp
sudo chmod +x /usr/local/bin/wp

# Delete temporary working directory
log "Cleaning up temporary workspace at $WP_TMP_DIR..."
rm -rf "$WP_TMP_DIR"

log "System update and cleanup completed successfully."

# --- 14. Final actions --- #

# Restrict wp-config.php permissions for security
log "Applying final permissions to wp-config.php..."
sudo chmod 640 "$WP_PATH/wp-config.php"
log "wp-config.php permissions set to 640 (owner read/write only)."

# Done
log "WordPress deployment completed successfully. Exiting..."