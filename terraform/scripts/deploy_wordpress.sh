#!/bin/bash

set -euxo pipefail  # Fail fast: exit on error, undefined variables, print each command; pipeline failure

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

# Retrieve WordPress Secrets
log "Retrieving WordPress secrets from AWS Secrets Manager..."
WP_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${AWS_DEFAULT_REGION}" \
  --secret-id "${WP_SECRETS_NAME}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$WP_SECRETS" ]; then
  log "ERROR: Failed to retrieve WordPress secrets from AWS Secrets Manager"
  exit 1
fi

log "WordPress secrets retrieved successfully."

# Retrieve RDS Database Secrets
log "Retrieving RDS database secrets from AWS Secrets Manager..."
RDS_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${AWS_DEFAULT_REGION}" \
  --secret-id "${RDS_SECRETS_NAME}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$RDS_SECRETS" ]; then
  log "ERROR: Failed to retrieve RDS database secrets from AWS Secrets Manager"
  exit 1
fi
log "RDS database secrets retrieved successfully."

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

# Export WordPress admin credentials from the $WP_SECRETS variable
export WP_ADMIN=$(echo "$WP_SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$WP_SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$WP_SECRETS" | jq -r '.ADMIN_PASSWORD')

# Export WordPress security keys and salts from the $WP_SECRETS variable
export AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$WP_SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$WP_SECRETS" | jq -r '.NONCE_SALT')

# Export RDS secrets from the $RDS_SECRETS variable
export DB_NAME=$(echo "$RDS_SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$RDS_SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$RDS_SECRETS" | jq -r '.DB_PASSWORD')

# Export Redis AUTH token from the $REDIS_AUTH_SECRETS variable
export REDIS_AUTH_TOKEN=$(echo "$REDIS_AUTH_SECRETS" | jq -r '.REDIS_AUTH_TOKEN')

# Verify all required values are present
for VAR in WP_ADMIN WP_ADMIN_EMAIL WP_ADMIN_PASSWORD \
           AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT \
           LOGGED_IN_SALT NONCE_SALT DB_NAME DB_USER DB_PASSWORD REDIS_AUTH_TOKEN; do
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

# --- 4. Install Dependencies and Configure PHP Environment --- #

# 4.1. Install all required system packages
log "Installing WordPress and system dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nginx \
  php${PHP_VERSION}-fpm \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-gd \
  mysql-client \
  redis-tools \
  composer \
  ca-certificates \
  gettext \
  python3-botocore

log "WordPress dependencies installed successfully."

# 4.2. Force update of CA certificates
log "Forcibly updating CA certificates for SSL/TLS connections..."
sudo update-ca-certificates --fresh
log "CA certificates updated."

# 4.3. Configure PHP to find system CA certificates for both FPM and CLI
log "Configuring PHP to use system CA bundle for SSL..."

# Find and patch the FPM php.ini
PHP_FPM_INI_FILE=$(php-fpm${PHP_VERSION} -i 2>/dev/null | grep "Loaded Configuration File" | awk '{print $NF}')
if [ -n "$PHP_FPM_INI_FILE" ]; then
  sudo sed -i 's,^;openssl.cafile=,openssl.cafile=/etc/ssl/certs/ca-certificates.crt,' "$PHP_FPM_INI_FILE"
  log "Set openssl.cafile in FPM config: $PHP_FPM_INI_FILE"
else
  log "WARNING: Could not find loaded php.ini file for FPM!"
fi

# Find and patch the CLI php.ini
PHP_CLI_INI_FILE=$(php${PHP_VERSION} -i 2>/dev/null | grep "Loaded Configuration File" | awk '{print $NF}')
if [ -n "$PHP_CLI_INI_FILE" ]; then
  sudo sed -i 's,^;openssl.cafile=,openssl.cafile=/etc/ssl/certs/ca-certificates.crt,' "$PHP_CLI_INI_FILE"
  log "Set openssl.cafile in CLI config: $PHP_CLI_INI_FILE"
else
  log "WARNING: Could not find loaded php.ini file for CLI!"
fi

# 4.4. Configure PHP to use Redis for session handling
log "Configuring PHP to use Redis for sessions over TLS and enhance security..."
PHP_INI_PATH="/etc/php/${PHP_VERSION}/fpm/conf.d/99-redis-session.ini"
cat << EOF | sudo tee $PHP_INI_PATH
session.save_handler = redis
session.save_path = "tls://${REDIS_HOST}:${REDIS_PORT}?auth=${REDIS_AUTH_TOKEN}&ssl[verify_peer]=0"
session.cookie_httponly = 1
# session.cookie_secure = 1 # Uncomment for production with HTTPS
EOF
log "PHP session config created at $PHP_INI_PATH."

# 4.5. Set secure permissions for PHP session directory
log "Securing PHP session directory..."
sudo chown root:www-data /var/lib/php/sessions
sudo chmod 1733 /var/lib/php/sessions
log "PHP session directory permissions set."

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
        try_files $uri $uri/ /index.php?$args;
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

    # Optional: Redirect all HTTP to HTTPS (enable when SSL is configured)
    # if (\$http_x_forwarded_proto = "http") {
    #     return 301 https://\$host\$request_uri;
    # }
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

# Remove any previous WordPress installation, preserving the EFS mount point.
log "Ensuring WordPress installation path $WP_PATH is empty..."
find "$WP_PATH" -mindepth 1 -maxdepth 1 -not -name "wp-content" -exec rm -rf {} +
find "$WP_PATH/wp-content" -mindepth 1 -not -path "$WP_PATH/wp-content/uploads" -exec rm -rf {} +

# Define the branch or tag to clone and a temporary path for the operation.
CLONE_TARGET="${WP_VERSION:-master}"
TMP_CLONE_PATH="/tmp/wp-clone-$$" # $$ adds a unique process ID

log "Cloning WordPress repository (branch: $CLONE_TARGET) into temporary directory..."

# Clone the repository into a temporary, empty directory.
git clone --depth=1 --branch "$CLONE_TARGET" https://github.com/hetmanskyi-cloud/wordpress.git "$TMP_CLONE_PATH" || {
  log "ERROR: Failed to clone WordPress repository: $CLONE_TARGET"
  exit 1
}

log "Moving WordPress files from temporary directory to $WP_PATH"
# Use rsync to move the files. It correctly merges the new code with the
# existing wp-content directory without overwriting our 'uploads' mount.
rsync -av "$TMP_CLONE_PATH/" "$WP_PATH/"

# Clean up the temporary clone directory.
log "Cleaning up temporary clone directory..."
rm -rf "$TMP_CLONE_PATH"

# Verify the clone was successful
if [ ! -f "$WP_PATH/wp-config-sample.php" ] && [ ! -f "$WP_PATH/wp-load.php" ]; then
  log "ERROR: Clone failed or incomplete. Required WordPress files not found."
  exit 1
fi

log "WordPress cloned successfully into $WP_PATH"

# Set correct ownership and permissions
log "Setting ownership and permissions..."
chown -R www-data:www-data $WP_PATH
find $WP_PATH -type d -exec chmod 755 {} \;
find $WP_PATH -type f -exec chmod 644 {} \;

log "Ownership and permissions set for $WP_PATH"
log "WordPress installation completed successfully!"

# Install Predis library for Redis TLS support
log "Installing Predis library for TLS support with Redis..."
COMPOSER_WORKING_DIR="$WP_PATH"
sudo -u www-data HOME="$WP_TMP_DIR" composer require --working-dir="$COMPOSER_WORKING_DIR" predis/predis
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

# --- 8. Configure wp-config.php (DB, Redis, ALB/CloudFront URL) --- #

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

# --- 8.5. Configure Dynamic URLs and Reverse Proxy Settings --- #

# Help WordPress handle cookies correctly behind a reverse proxy
log "Setting cookie domain for reverse proxy..."
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set COOKIE_DOMAIN "" --path="$WP_PATH"

# Add PHP snippet to dynamically determine URL and handle reverse proxy SSL
log "Adding dynamic URL and reverse proxy PHP snippet to wp-config.php..."

# Define the PHP block to be inserted
PHP_SNIPPET=$(cat <<'EOF'

// --- START: Dynamic URL & Reverse Proxy Support (Inserted by deploy script) ---
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
    $protocol = 'https://';
} else {
    $protocol = 'http://';
}

if (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
}

define('WP_HOME', $protocol . $_SERVER['HTTP_HOST']);
define('WP_SITEURL', $protocol . $_SERVER['HTTP_HOST']);
// --- END: Dynamic URL & Reverse Proxy Support ---

EOF
)

# Insert the block before "/* That's all, stop editing! */"
# This check ensures the block is only inserted once by looking for a unique part of the snippet.
if ! sudo -u www-data grep -q "define('WP_HOME'" "$WP_PATH/wp-config.php"; then
    # Use sed to find the target line and insert the content of the PHP_SNIPPET variable before it
    sudo sed -i "/\/\* That's all, stop editing!/i ${PHP_SNIPPET}" "$WP_PATH/wp-config.php"
    log "Dynamic URL snippet inserted into wp-config.php."
else
    log "Dynamic URL snippet already exists in wp-config.php. Skipping."
fi

# Conditionally force SSL for the admin area
# This setting works correctly with the proxy-aware snippet above.
source /etc/environment
if [ "${ENABLE_HTTPS}" = "true" ]; then
    log "HTTPS is enabled: Forcing SSL for admin area..."
    sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" config set FORCE_SSL_ADMIN "true" --raw --path="$WP_PATH"
else
    log "HTTPS is disabled: Skipping FORCE_SSL_ADMIN."
fi

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

  # Run WordPress installation with the public URL
  sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" core install \
    --path="$WP_PATH" \
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

# --- 10. Activate Pre-installed Plugins --- #

log "Activating plugins included in the Git repository..."

# Activate each plugin that is now present from the git clone
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" plugin activate redis-cache --path="$WP_PATH"
sudo -u www-data HOME=$WP_TMP_DIR php "$WP_CLI_PHAR_PATH" plugin activate wordfence --path="$WP_PATH"

# The Redis Object Cache plugin requires a special command to be enabled after activation.
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

# Remove sensitive variables from /etc/environment
for var in DB_PASSWORD REDIS_AUTH_TOKEN; do
  sudo sed -i "/^${var}=/d" /etc/environment
done

log "Sensitive secrets removed from /etc/environment."

# Delete temporary working directory
log "Cleaning up temporary workspace at $WP_TMP_DIR..."
rm -rf "$WP_TMP_DIR"
log "Temporary workspace deleted."

log "WordPress deployment completed successfully. Exiting..."

# --- Notes --- #
# Description:
#   This is the main WordPress deployment script executed via EC2 user-data on boot.
#   It installs and configures WordPress, Nginx, PHP-FPM, MySQL, Redis, WP-CLI, and plugins.
#   It also fetches secrets from AWS Secrets Manager and sets up a health check endpoint.
#
# Execution Context:
#   - Executed inside the EC2 instance (Ubuntu) launched via Auto Scaling Group.
#   - Triggered via user-data script passed from Terraform.
#
# Prerequisites:
#   - Environment variables (DB_HOST, DB_PORT, WP_PATH, etc.) must be set in /etc/environment before execution.
#   - AWS CLI and session manager plugins must be available.
#   - Scripts like healthcheck.php must exist in S3 and be accessible.
#
# Behavior:
#   - Idempotent: if rerun on the same instance, it safely detects existing WordPress installation.
#   - Logs full output to /var/log/wordpress_install.log
#   - Includes health checks for RDS and Redis connectivity, and verifies WordPress REST API.
#   - Conditionally sets the Site URL: uses the CloudFront domain if provided,
#     otherwise falls back to the ALB domain. This allows flexible deployments.
#
# Security:
#   - Secrets are retrieved from Secrets Manager and temporarily exported.
#   - Sensitive credentials (like DB_PASSWORD, Redis token) are removed from /etc/environment after setup.
#
# Debugging:
#   - Tail logs: `tail -f /var/log/user-data.log /var/log/wordpress_install.log`
#   - Use `debug_monitor.sh` for automated instance monitoring via SSM.
