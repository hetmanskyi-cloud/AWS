#!/bin/bash

set -euxo pipefail  # Fail fast: exit on error, undefined variables, or pipeline failure; print each command

# Redirect all stdout and stderr to /var/log/wordpress_install.log as well as console
mkdir -p /var/log
exec 1> >(tee -a /var/log/wordpress_install.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting WordPress installation..."

# --- 1. Install base packages needed for WordPress, minus curl/unzip (which are installed in user_data.sh.tpl) --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing base packages..."
apt-get update -q || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: apt-get update failed"; exit 1; }
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  jq \
  netcat-openbsd

# --- 2. Wait for MySQL (RDS) to become available (up to 60 seconds) --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking if MySQL is ready on host: ${DB_HOST}, port: ${DB_PORT}..."
for i in {1..12}; do
  if nc -z "${DB_HOST}" "${DB_PORT}"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL is reachable!"
    break
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL not ready yet. Retrying in 5 seconds... (${i}/12)"
  sleep 5
done

# Final check after loop
if ! nc -z "${DB_HOST}" "${DB_PORT}"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: MySQL not available after 60s. Exiting."
  exit 1
fi

# --- 3. Retrieve secrets from AWS Secrets Manager --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Retrieving secrets from AWS Secrets Manager..."
SECRETS=$(aws secretsmanager get-secret-value \
  --region "${AWS_DEFAULT_REGION}" \
  --secret-id "${SECRET_NAME}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$SECRETS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Secrets retrieved successfully."

# Export secrets for WordPress configuration
export DB_NAME=$(echo "$SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$SECRETS" | jq -r '.DB_PASSWORD')

export WP_ADMIN=$(echo "$SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$SECRETS" | jq -r '.ADMIN_PASSWORD')

# Export WordPress security keys
export AUTH_KEY=$(echo "$SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$SECRETS" | jq -r '.NONCE_SALT')

# Verify all required values are present
for VAR in DB_NAME DB_USER DB_PASSWORD WP_ADMIN WP_ADMIN_EMAIL WP_ADMIN_PASSWORD \
           AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
  if [ -z "${!VAR}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Required secret variable $VAR is empty."
    exit 1
  fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All secrets successfully retrieved and exported."

# --- 4. Install WordPress dependencies (Nginx, PHP, MySQL client, etc.) --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing WordPress dependencies..."
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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to install WordPress dependencies."
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress dependencies installed successfully."

# --- 5. Configure Nginx --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring Nginx..."

# Ensure /var/www/html exists before configuring Nginx
if [ ! -d "/var/www/html" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: /var/www/html directory does not exist! Creating..."
  mkdir -p /var/www/html
fi

# Detect correct PHP-FPM socket path dynamically
PHP_SOCK=$(find /run /var/run -name "php${PHP_VERSION}-fpm.sock" 2>/dev/null | head -n 1)
if [ -z "$PHP_SOCK" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: PHP-FPM socket not found!"
    exit 1
fi

# Restart PHP-FPM to ensure it's running and the socket is active
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting PHP-FPM..."
systemctl restart php${PHP_VERSION}-fpm

# Ensure PHP-FPM is running
systemctl is-active php${PHP_VERSION}-fpm || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: PHP-FPM is not running!"; exit 1; }

# Configure Nginx virtual host for WordPress
cat <<EOL > /etc/nginx/sites-available/wordpress
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting Nginx..."
systemctl restart nginx

# Optimizations for scalability (Auto Scaling group)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Adjusting Nginx for high load and Auto Scaling..."

# Optimize Nginx for Auto Scaling (safe edit inside events block)
sed -i 's/^\s*worker_connections\s\+[0-9]\+;/    worker_connections 1024;/' /etc/nginx/nginx.conf
sed -i 's/worker_processes .*/worker_processes auto;/' /etc/nginx/nginx.conf

# Restart Nginx to apply the new configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting Nginx to apply new configuration..."
systemctl restart nginx

# --- 6. Download and install WordPress --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading and installing WordPress from GitHub..."

# Remove any previous WordPress installation (if files exist)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removing old WordPress installation if files exist..."
if [ "$(ls -A /var/www/html)" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removing old WordPress files..."
  rm -rf /var/www/html/*  # Remove all files if they exist
fi

# Define the branch, tag, or commit to clone
GIT_COMMIT="master" # Replace with a specific commit or tag if needed

# Clone the WordPress repository directly into /var/www/html (NOT into subfolder /wordpress)
git clone --depth=1 --branch "$GIT_COMMIT" https://github.com/hetmanskyi-cloud/wordpress.git /var/www/html || {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to clone WordPress repository!"
  exit 1
}

# Verify the clone was successful
if [ ! -f "/var/www/html/wp-config-sample.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: WordPress clone failed or incomplete!"
  exit 1
fi

# Set correct ownership and permissions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting ownership and permissions..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress installation completed successfully!"

# --- 7. Install WP-CLI --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing WP-CLI..."

# Download WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Verify WP-CLI download
if ! php wp-cli.phar --info > /dev/null 2>&1; then
  echo "ERROR: WP-CLI download failed or is corrupted!"
  exit 1
fi

# Make WP-CLI executable and move to global location
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# WP-CLI Cache Setup
mkdir -p /tmp/wp-cli-cache
export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WP-CLI installed successfully!"

# --- 8. Configure wp-config.php for RDS Database (MySQL), ALB, and ElastiCache (Redis) --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring wp-config.php for WordPress..."

# Ensure wp-config-sample.php exists; if missing, download it
if [ ! -f "/var/www/html/wp-config-sample.php" ]; then
  echo "WARNING: wp-config-sample.php not found! Downloading..."
  curl -o /var/www/html/wp-config-sample.php https://raw.githubusercontent.com/WordPress/WordPress/master/wp-config-sample.php
fi

# Check if necessary environment variables are set
for VAR in DB_NAME DB_USER DB_PASSWORD DB_HOST DB_PORT \
           AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY \
           AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT \
           AWS_LB_DNS REDIS_HOST REDIS_PORT; do
  if [ -z "${!VAR}" ]; then
    echo "ERROR: Missing required environment variable $VAR!"
    exit 1
  fi
done

# Generate wp-config.php safely using WP-CLI
sudo -u www-data HOME=/tmp wp config create --path=/var/www/html \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --dbhost="$DB_HOST" \
  --dbprefix="wp_" \
  --skip-check \
  --force

# Insert additional constants (security keys, Redis settings, ALB configuration)
sudo -u www-data HOME=/tmp wp config set AUTH_KEY "$AUTH_KEY" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set SECURE_AUTH_KEY "$SECURE_AUTH_KEY" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set LOGGED_IN_KEY "$LOGGED_IN_KEY" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set NONCE_KEY "$NONCE_KEY" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set AUTH_SALT "$AUTH_SALT" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set SECURE_AUTH_SALT "$SECURE_AUTH_SALT" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set LOGGED_IN_SALT "$LOGGED_IN_SALT" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set NONCE_SALT "$NONCE_SALT" --path=/var/www/html

# Configure Redis object cache settings
sudo -u www-data HOME=/tmp wp config set WP_REDIS_HOST "$REDIS_HOST" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set WP_REDIS_PORT "$REDIS_PORT" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set WP_CACHE "true" --raw --path=/var/www/html

# Set the correct protocol and domain dynamically from ALB
sudo -u www-data HOME=/tmp wp config set WP_SITEURL "http://$AWS_LB_DNS" --path=/var/www/html
sudo -u www-data HOME=/tmp wp config set WP_HOME "http://$AWS_LB_DNS" --path=/var/www/html

# Verify wp-config.php was successfully created
if [ ! -f "/var/www/html/wp-config.php" ]; then
  echo "ERROR: wp-config.php creation failed!"
  exit 1
fi

# Set correct ownership and permissions (final hardening will be at the end)
sudo chown www-data:www-data /var/www/html/wp-config.php
sudo chmod 644 /var/www/html/wp-config.php
echo "Ownership and permissions set temporarily for wp-config.php"

# Test database connection explicitly
if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME;" > /dev/null 2>&1; then
  echo "Database connection successful!"
else
  echo "ERROR: Unable to connect to the database. Check your credentials and network connectivity."
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config.php created and validated successfully."

# --- 9. Initialize WordPress database and admin user --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initializing WordPress database and admin user..."

# Check if WordPress is already installed before attempting installation
if sudo -u www-data HOME=/tmp wp core is-installed --path=/var/www/html; then
    # Exit code 0 means WordPress IS installed
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress is already installed. Skipping core installation."
else    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress not installed. Proceeding with core installation..."

# Initialize WordPress using WP-CLI
sudo -u www-data HOME=/tmp wp core install --path=/var/www/html \
  --url="http://${AWS_LB_DNS}" \
  --title="${WP_TITLE}" \
  --admin_user="${WP_ADMIN}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --skip-email \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --dbname="${DB_NAME}" \
  --dbhost="${DB_HOST}"

# Verify WordPress Initialization
if sudo -u www-data HOME=/tmp wp core is-installed --path=/var/www/html; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress initialization completed successfully!"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: WordPress initialization failed!"
  exit 1
fi

# Clean up WP-CLI cache
rm -rf /tmp/wp-cli-cache

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress initialization completed successfully!"

# --- 10. Install common WordPress plugins --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing common WordPress plugins..."

# Ensure WordPress is installed before proceeding
if ! sudo -u www-data HOME=/tmp wp core is-installed --path=/var/www/html; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: WordPress is not installed. Cannot proceed with plugin installation."
  exit 1
fi

# List of plugins to install
PLUGINS=("wp-super-cache" "wordfence")

# Install and activate each plugin individually
for PLUGIN in "${PLUGINS[@]}"; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing plugin: $PLUGIN"
  if sudo -u www-data HOME=/tmp wp plugin install "$PLUGIN" --activate --path=/var/www/html; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Plugin $PLUGIN installed and activated successfully."
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to install or activate plugin: $PLUGIN"
    exit 1
  fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All common WordPress plugins installed and activated successfully!"

# --- 11. Configure and enable Redis Object Cache --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Redis Object Cache..."

# Log Redis host and port for reference
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using Redis at ${REDIS_HOST}:${REDIS_PORT}"

# Check if Redis server is reachable before enabling the plugin
if ! nc -z "$REDIS_HOST" "$REDIS_PORT"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Redis server is not reachable at ${REDIS_HOST}:${REDIS_PORT}"
fi

# Install and activate the Redis Object Cache plugin (safe to run multiple times)
sudo -u www-data HOME=/tmp wp plugin install redis-cache --activate --path=/var/www/html

# Enable Redis object caching; fail the script if unsuccessful
if ! sudo -u www-data HOME=/tmp wp redis enable --path=/var/www/html; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Failed to enable Redis caching."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis caching enabled successfully."
fi

# Optional: Check Redis connection status
REDIS_STATUS=$(sudo -u www-data HOME=/tmp wp redis status --path=/var/www/html | grep -i "Status: Connected" || true)

if [ -n "$REDIS_STATUS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis is connected successfully."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Redis is not connected properly."
fi

# --- 12. Create ALB health check endpoint using provided content --- #

%{ if enable_s3_script }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading healthcheck file from S3: ${healthcheck_s3_path}"
aws s3 cp "${healthcheck_s3_path}" /var/www/html/healthcheck.php --region ${AWS_DEFAULT_REGION}
if [ $? -ne 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to download healthcheck.php from S3"
  exit 1
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALB health check endpoint created successfully from S3"
fi
%{ else }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Writing embedded healthcheck content..."
echo "${healthcheck_content_b64}" | base64 --decode > /var/www/html/healthcheck.php
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALB health check endpoint created successfully from embedded content"
%{ endif }

# Set ownership and permissions for healthcheck file
sudo chown www-data:www-data /var/www/html/healthcheck.php
sudo chmod 644 /var/www/html/healthcheck.php

# --- 13. Safe system update and cleanup --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Performing safe system update..."

# Update packages without interactive prompts
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --only-upgrade
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends

# Clean up unused packages and cache
apt-get autoremove -y --purge
apt-get clean

echo "[$(date '+%Y-%m-%d %H:%M:%S')] System update and cleanup completed successfully!"

# --- 14. Final hardening --- # 

# Restrict wp-config.php permissions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applying final permissions to wp-config.php..."
sudo chmod 640 /var/www/html/wp-config.php
echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config.php permissions set to 640 (owner read/write only)."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress Deployment Script Version: 1.0.0 installed successfully!"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress deployment completed successfully. Exiting..."
exit 0