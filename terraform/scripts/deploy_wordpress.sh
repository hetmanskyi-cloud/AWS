#!/bin/bash

set -euxo pipefail  # Fail fast: exit on error, undefined variables, or pipeline failure; print each command

# Load env vars from user-data export
set -a
source /etc/environment
set +a

# Unified logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- 1. Start logging and ensure required base packages are installed --- #

# Redirect all stdout and stderr to log file and console
exec 1> >(tee -a /var/log/wordpress_install.log) 2>&1
log "Starting WordPress installation..."

# Ensure base packages (jq, netcat) are installed
log "Ensuring base packages (jq, netcat-openbsd) are installed..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  jq \
  netcat-openbsd
log "Base packages verified and installed if missing."

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

# Write critical secrets to /etc/environment for use in healthcheck
echo "DB_NAME=\"$DB_NAME\"" | sudo tee -a /etc/environment
echo "DB_USER=\"$DB_USER\"" | sudo tee -a /etc/environment
echo "DB_PASSWORD=\"$DB_PASSWORD\"" | sudo tee -a /etc/environment
echo "REDIS_AUTH_TOKEN=\"$REDIS_AUTH_TOKEN\"" | sudo tee -a /etc/environment

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
  redis-tools \
  composer

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

# Restart Nginx to apply new configuration...
log "Restarting Nginx to apply new configuration..."
systemctl restart nginx
if [ $? -ne 0 ]; then
    log "ERROR: Failed to restart Nginx after applying optimizations!"
    exit 1
fi

# --- 6. Download and install WordPress and Predis library --- #

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

# Install Predis library for Redis TLS support
log "Installing Predis library for TLS support with Redis..."
COMPOSER_WORKING_DIR="$WP_PATH"
sudo -u www-data composer require --working-dir="$COMPOSER_WORKING_DIR" predis/predis
if [ $? -ne 0 ]; then
  log "ERROR: Failed to install Predis library."
  exit 1
fi
log "Predis library installed successfully."

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

log "WP-CLI downloaded and made executable at ${WP_TMP_DIR}/wp-cli.phar. It will be moved to /usr/local/bin/wp later."

# --- 8. Configure wp-config.php for RDS Database (MySQL), ALB, and ElastiCache (Redis) --- #

# 8.1. Preparing the configuration wp-config.php
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

# 8.2. Generate wp-config.php as www-data
log "Create the main wp-config.php file..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config create \
  --path="$WP_PATH" \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --dbhost="$DB_HOST" \
  --dbprefix="wp_" \
  --skip-check \
  --force

# 8.3. Set up security keys and salts
log "Set up security keys and salts..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set AUTH_KEY "$AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set SECURE_AUTH_KEY "$SECURE_AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set LOGGED_IN_KEY "$LOGGED_IN_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set NONCE_KEY "$NONCE_KEY" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set AUTH_SALT "$AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set SECURE_AUTH_SALT "$SECURE_AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set LOGGED_IN_SALT "$LOGGED_IN_SALT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set NONCE_SALT "$NONCE_SALT" --path="$WP_PATH"

# 8.4. Configure Redis Object Cache
log "Configure Redis Object Cache..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_HOST "$REDIS_HOST" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_PORT "$REDIS_PORT" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_PASSWORD "$REDIS_AUTH_TOKEN" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_CLIENT "predis" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_REDIS_SCHEME "tls" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_CACHE "true" --raw --path="$WP_PATH"

# 8.5. Set site URLs from ALB DNS
log "Set site URLs from ALB DNS..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_SITEURL "http://$AWS_LB_DNS" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_HOME "http://$AWS_LB_DNS" --path="$WP_PATH"

# 8.6. Final verifications and permissions
log "Final verifications and permissions for wp-config.php..."

# Verify wp-config.php was created
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  log "ERROR: wp-config.php creation failed!"
  exit 1
fi

# Set ownership and permissions
sudo chown www-data:www-data "$WP_PATH/wp-config.php"
sudo chmod 644 "$WP_PATH/wp-config.php"
log "Ownership and permissions set for wp-config.php"

# 8.7 Optional: Verify DB connection over SSL
if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
    --ssl-ca="/etc/ssl/certs/rds-combined-ca-bundle.pem" \
    -e "USE $DB_NAME;" > /dev/null 2>&1; then
  log "Database SSL connection successful via CLI."
else
  log "ERROR: Unable to connect to the database with SSL."
  exit 1
fi

log "wp-config.php created and validated successfully."

# --- 8.8 Enable WordPress Debug Logging --- #

log "Enabling WP_DEBUG and log file path..."

# Ensure log file exists and is writable by www-data
sudo touch /var/log/wordpress.log
sudo chown www-data:www-data /var/log/wordpress.log
sudo chmod 644 /var/log/wordpress.log

log "Debug log file /var/log/wordpress.log created and permissions set."

# Enable WP_DEBUG and configure debug log path in wp-config.php
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_DEBUG true --raw --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_DEBUG_LOG "/var/log/wordpress.log" --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set WP_DEBUG_DISPLAY false --raw --path="$WP_PATH"

log "WordPress debug logging enabled."

# --- 9. Initialize WordPress database and admin user --- #

log "Starting WordPress database initialization..."
SSL_CA_PATH="/etc/ssl/certs/rds-combined-ca-bundle.pem"

# Ensure www-data has write permissions to wp-content
if ! sudo -u www-data test -w "$WP_PATH/wp-content"; then
  log "WARNING: www-data user does not have write permissions to wp-content directory!"
  log "Fixing permissions..."
  chown -R www-data:www-data "$WP_PATH/wp-content"
  chmod -R 755 "$WP_PATH/wp-content"
  log "Permissions updated."
fi

# Ensure uploads directory exists with proper permissions
if [ ! -d "$WP_PATH/wp-content/uploads" ]; then
  log "Creating uploads directory..."
  mkdir -p "$WP_PATH/wp-content/uploads"
  chown www-data:www-data "$WP_PATH/wp-content/uploads"
  chmod 755 "$WP_PATH/wp-content/uploads"
fi

# Test database SSL connection using PHP (mysqli)
log "Testing database SSL connection using PHP mysqli..."
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

# Add MYSQL_SSL_CA to wp-config.php
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
      
      # Extended diagnostics for database connection
      log "Running extended diagnostics..."
      
      # Check database connection using wp-cli with debug mode
      log "Checking database connection via wp-cli:"
      sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" db check --path="$WP_PATH" --debug || true
      
      # Check network connectivity to database
      log "Checking network connectivity to database:"
      nc -zv "$DB_HOST" "$DB_PORT" || log "Cannot connect to database at $DB_HOST:$DB_PORT"
      
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

# --- 10. Configure and enable Redis Object Cache --- #

log "Setting up Redis Object Cache..."

# Basic connectivity check (optional but useful)
if ! nc -z "$REDIS_HOST" "$REDIS_PORT"; then
  log "WARNING: Redis server is not reachable at ${REDIS_HOST}:${REDIS_PORT}"
fi

# Install and activate Redis Object Cache plugin
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" plugin install redis-cache --activate --path="$WP_PATH"

# Enable Redis caching
if sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" redis enable --path="$WP_PATH"; then
  log "Redis Object Cache enabled successfully."
else
  log "WARNING: Failed to enable Redis Object Cache via WP-CLI."
fi

# --- 11. Create ALB health check endpoint from S3 --- #

if [ -n "${HEALTHCHECK_S3_PATH:-}" ]; then
  log "Downloading healthcheck.php from S3: ${HEALTHCHECK_S3_PATH}"
  sudo aws s3 cp "${HEALTHCHECK_S3_PATH}" "$WP_PATH/healthcheck.php" --region "${AWS_DEFAULT_REGION}" 2>&1 | tee -a /var/log/user-data.log

  if [ $? -ne 0 ]; then
    log "ERROR: Failed to download healthcheck.php from S3"
    exit 1
  else
    log "ALB health check endpoint created successfully from S3"
    
    # Set ownership and permissions only if file was downloaded
    sudo chown www-data:www-data "$WP_PATH/healthcheck.php"
    sudo chmod 644 "$WP_PATH/healthcheck.php"
  fi
else
  log "HEALTHCHECK_S3_PATH is not defined. Skipping healthcheck setup."
fi

# --- 12. Final cleanup and security steps --- #

# Update package index
log "Performing safe system update..."
DEBIAN_FRONTEND=noninteractive apt-get update

# Clean up APT package cache
log "Cleaning up APT package cache..."
apt-get clean

# Move WP-CLI to a permanent location
log "Installing wp-cli to /usr/local/bin/wp..."
sudo mv "$WP_CLI_PHAR_PATH" /usr/local/bin/wp
sudo chmod +x /usr/local/bin/wp
log "wp-cli installed successfully."

# Remove only sensitive variables from /etc/environment
log "Clearing sensitive secrets from /etc/environment..."
sudo sed -i '/^DB_PASSWORD=/d' /etc/environment
sudo sed -i '/^REDIS_AUTH_TOKEN=/d' /etc/environment
log "Sensitive secrets removed from /etc/environment."

# Delete temporary working directory
log "Cleaning up temporary workspace at $WP_TMP_DIR..."
rm -rf "$WP_TMP_DIR"
log "Temporary workspace deleted."

# Done
log "WordPress deployment completed successfully. Exiting..."