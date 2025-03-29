#!/bin/bash

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Enable debug mode
export DEBUG=true
[ "${DEBUG:-false}" = "true" ] && set -x

# Load environment variables (AWS_DEFAULT_REGION, SECRET_NAME, etc.)
source /etc/environment

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
export AUTH_KEY=$(echo "$SECRETS" | jq -r '.auth_key')
export SECURE_AUTH_KEY=$(echo "$SECRETS" | jq -r '.secure_auth_key')
export LOGGED_IN_KEY=$(echo "$SECRETS" | jq -r '.logged_in_key')
export NONCE_KEY=$(echo "$SECRETS" | jq -r '.nonce_key')
export AUTH_SALT=$(echo "$SECRETS" | jq -r '.auth_salt')
export SECURE_AUTH_SALT=$(echo "$SECRETS" | jq -r '.secure_auth_salt')
export LOGGED_IN_SALT=$(echo "$SECRETS" | jq -r '.logged_in_salt')
export NONCE_SALT=$(echo "$SECRETS" | jq -r '.nonce_salt')

# Extract values from the JSON and export those that must be used in other processes
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing and exporting secrets..."

# Debug: Print the structure of the secrets
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: Secrets structure:"
echo "$SECRETS" | jq '.'

export DB_NAME=$(echo "$SECRETS" | jq -r '.db_name')
export DB_USER=$(echo "$SECRETS" | jq -r '.db_user')
export DB_PASSWORD=$(echo "$SECRETS" | jq -r '.db_password')
export WP_ADMIN=$(echo "$SECRETS" | jq -r '.admin_user')
export WP_ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.admin_email')
export WP_ADMIN_PASSWORD=$(echo "$SECRETS" | jq -r '.admin_password')

# Debug: Print the values of the exported variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: Exported variables:"
echo "DB_NAME=$DB_NAME"
echo "DB_USER=$DB_USER"
echo "DB_PASSWORD=${DB_PASSWORD:0:3}***" # Print only first 3 chars for security
echo "WP_ADMIN=$WP_ADMIN"
echo "WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL"
echo "WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD:0:3}***" # Print only first 3 chars for security

# Verify all required values are present
for VAR in DB_NAME DB_USER DB_PASSWORD WP_ADMIN WP_ADMIN_EMAIL WP_ADMIN_PASSWORD; do
  if [ -z "${!VAR}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Required secret variable $VAR is empty."
    exit 1
  fi
done

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

# --- 6. Download and install WordPress --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading and installing WordPress from GitHub..."

# Ensure target directory exists
mkdir -p /var/www/html

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

# --- 7. Configure WordPress (wp-config.php) for RDS Database (MySQL), ALB, and ElastiCache (Redis) --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring WordPress..."

# Move into WordPress root directory
cd /var/www/html || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Cannot access /var/www/html!"; exit 1; }

# Ensure wp-config-sample.php exists; if missing, download a fresh copy
if [ ! -f "wp-config-sample.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: wp-config-sample.php not found! Downloading..."
  curl -O https://raw.githubusercontent.com/WordPress/WordPress/master/wp-config-sample.php
fi

# Log to verify wp-config-sample.php now exists
echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config-sample.php found."

# Copy sample configuration to wp-config.php if it doesn't already exist
if [ ! -f "wp-config.php" ]; then
  cp wp-config-sample.php wp-config.php
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config.php created from wp-config-sample.php"
fi

# Set correct ownership and permissions for wp-config.php
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting correct ownership and permissions for wp-config.php..."
chown www-data:www-data /var/www/html/wp-config.php
chmod 644 /var/www/html/wp-config.php

# Log wp-config.php details for verification
echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config.php exists at: $(ls -l /var/www/html/wp-config.php)"

# --- Replace with custom template using envsubst --- #

# Check that wp-config-template.php is available
if [ ! -f "/tmp/wp-config-template.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: wp-config-template.php is missing in /tmp/"
  exit 1
fi

# Export all required env variables
export DB_NAME DB_USER DB_PASSWORD DB_HOST DB_PORT \
        WP_TITLE PHP_VERSION REDIS_HOST REDIS_PORT AWS_LB_DNS \
        AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT

# Generate wp-config.php from template
# Use envsubst with an explicit list to avoid replacing PHP variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing wp-config-template.php with envsubst..."
envsubst '${DB_NAME} ${DB_PASSWORD} ${DB_HOST} ${DB_USER} \
${AUTH_KEY} ${SECURE_AUTH_KEY} ${LOGGED_IN_KEY} ${NONCE_KEY} \
${AUTH_SALT} ${SECURE_AUTH_SALT} ${LOGGED_IN_SALT} ${NONCE_SALT} \
${AWS_LB_DNS} ${REDIS_HOST} ${REDIS_PORT}' \
< /tmp/wp-config-template.php > /var/www/html/wp-config.php

# Verify the result
if [ ! -f "/var/www/html/wp-config.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to create wp-config.php!"
  exit 1
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config.php created successfully."
fi

# Set ownership and permissions again after replacement
chown www-data:www-data /var/www/html/wp-config.php
chmod 644 /var/www/html/wp-config.php

# Log debug output of the generated config
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Debug: Content of final wp-config.php"
cat /var/www/html/wp-config.php

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress configuration completed successfully!"

# --- 8. Install WP-CLI and run initial WordPress setup --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing WP-CLI..."

# Download the official WP-CLI Phar package
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Verify WP-CLI download is valid
if ! php wp-cli.phar --info > /dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: WP-CLI download failed or is corrupted!"
  exit 1
fi

# Make it executable and move to global location
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# WP-CLI Cache Setup
mkdir -p /tmp/wp-cli-cache
export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running WordPress core installation..."

# Navigate to the WordPress root directory
cd /var/www/html

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting WordPress file permissions before WP-CLI..."
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Wait until wp db check succeeds (max 60s)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for WordPress DB connection via wp-cli..."
for i in {1..12}; do
  if sudo -u www-data HOME=/tmp wp db check >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp db check succeeded after $((i * 5)) seconds."
    break
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $i: wp db check failed. Retrying in 5s..."
  sleep 5
done

# Final check
if ! sudo -u www-data HOME=/tmp wp db check >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: wp db check still failing after 60s. Exiting."
  exit 1
fi

# Install WordPress using WP-CLI as www-data user
sudo -u www-data HOME=/tmp wp core install \
  --url="http://${AWS_LB_DNS}" \
  --title="${WP_TITLE}" \
  --admin_user="${WP_ADMIN}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --skip-email

# Verify WordPress installation succeeded
if ! sudo -u www-data HOME=/tmp wp core is-installed; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: WordPress CLI installation failed!"
  exit 1
fi

# Clean up WP-CLI cache to free up space
rm -rf /tmp/wp-cli-cache

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress core installation completed successfully!"

# --- 9. Install common WordPress plugins --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing common WordPress plugins..."

# Install and activate plugins using WP-CLI
sudo -u www-data wp plugin install \
  wp-super-cache \
  wordfence \
  --activate || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to install some plugins!"
    exit 1
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Common WordPress plugins installed and activated successfully!"

# --- 10. Configure and enable Redis Object Cache --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Redis Object Cache..."

# Install and activate the Redis Object Cache plugin (safe to run multiple times)
sudo -u www-data wp plugin install redis-cache --activate

# Enable Redis object caching; fail the script if unsuccessful
if ! sudo -u www-data wp redis enable; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Failed to enable Redis caching."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis caching enabled successfully."
fi

# Optional: Check Redis connection status
REDIS_STATUS=$(sudo -u www-data wp redis status | grep -i "Status: Connected" || true)

if [ -n "$REDIS_STATUS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis is connected successfully."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Redis is not connected properly."
fi

# --- 11. Create ALB health check endpoint using provided content --- #

%{ if enable_s3_script }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading healthcheck file from S3: ${healthcheck_s3_path}"
aws s3 cp "${healthcheck_s3_path}" /var/www/html/healthcheck.php --region ${AWS_DEFAULT_REGION}
if [ $? -ne 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to download healthcheck.php from S3"
  exit 1
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALB healthcheck endpoint created successfully!"
fi
%{ else }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local healthcheck content..."
echo "${healthcheck_content_b64}" | base64 --decode > /var/www/html/healthcheck.php
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALB healthcheck endpoint created successfully!"
%{ endif }

# Set correct ownership and permissions for healthcheck file
sudo chown www-data:www-data /var/www/html/healthcheck.php
sudo chmod 644 /var/www/html/healthcheck.php

# --- 12. Safe system update and cleanup --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Performing safe system update..."
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --only-upgrade
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends
apt-get autoremove -y --purge
apt-get clean
echo "[$(date '+%Y-%m-%d %H:%M:%S')] System update and cleanup completed successfully!"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress Deployment Script Version: 1.0.0 installed successfully!"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress deployment completed successfully. Exiting..."
exit 0