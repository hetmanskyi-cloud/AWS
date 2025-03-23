#!/bin/bash
set -e # Exit script if any command fails

# Redirect all stdout and stderr to /var/log/wordpress_install.log as well as console
exec 1> >(tee -a /var/log/wordpress_install.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting WordPress installation..."

# 1. Install base packages needed for WordPress, minus curl/unzip (which are installed in user_data.sh.tpl).
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing base packages..."
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  jq \
  netcat-openbsd

# 2. Wait for MySQL (RDS) to become available (up to 60 seconds)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking if MySQL is ready on host: ${DB_HOST}, port: ${DB_PORT}..."
for i in {1..12}; do
  if nc -z "${DB_HOST}" "${DB_PORT}"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL is reachable!"
    break
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL not ready yet. Waiting 5 seconds..."
  sleep 5
done

# Final check after loop
if ! nc -z "${DB_HOST}" "${DB_PORT}"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: MySQL not available after 60s. Exiting."
  exit 1
fi

# 3. Retrieve secrets from AWS Secrets Manager
# Ensure AWS CLI is installed before attempting to retrieve secrets
if ! command -v aws &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: AWS CLI is not installed."
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Retrieving secrets from AWS Secrets Manager..."
SECRETS=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" --query 'SecretString' --output text)

# Verify secrets retrieval
if [ -z "$SECRETS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Secrets retrieved successfully."

# Extract values from the JSON
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing secrets..."
DB_NAME=$(echo "$SECRETS" | jq -r '.db_name')
DB_USERNAME=$(echo "$SECRETS" | jq -r '.db_username')
DB_PASSWORD=$(echo "$SECRETS" | jq -r '.db_password')
WP_ADMIN=$(echo "$SECRETS" | jq -r '.admin_user')
WP_ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.admin_email')
WP_ADMIN_PASSWORD=$(echo "$SECRETS" | jq -r '.admin_password')

# Verify all required values are present
for VAR in DB_NAME DB_USERNAME DB_PASSWORD WP_ADMIN WP_ADMIN_EMAIL WP_ADMIN_PASSWORD; do
  if [ -z "${!VAR}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Required secret variable $VAR is empty."
    exit 1
  fi
done

# 4. Install WordPress dependencies (Nginx, PHP, MySQL client, etc.)
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
  redis-tools \
  redis

# 5. Configure Nginx
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring Nginx..."

# Detect correct PHP socket path dynamically
PHP_SOCK=$(find /run /var/run -name "php${PHP_VERSION}-fpm.sock" 2>/dev/null | head -n 1)
if [ -z "$PHP_SOCK" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: PHP-FPM socket not found!"
    exit 1
fi

# Configure Nginx
cat <<EOL > /etc/nginx/sites-available/wordpress
server {
    listen 80;
    listen [::]:80;

    root /var/www/html/wordpress;
    index index.php index.html index.htm;

    server_name _;

    # ALB Support (Handle forwarded IPs)
    set_real_ip_from 0.0.0.0/0;
    real_ip_header X-Forwarded-For;

    # Support HTTPS via ALB
    set \$forwarded_https off;
    if (\$http_x_forwarded_proto = "https") {
        set \$forwarded_https on;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Process PHP files
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param HTTPS \$forwarded_https;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# Enable WordPress site and disable the default site
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 6. Download and install WordPress
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading and installing WordPress from GitHub..."

# Ensure /var/www/html exists
mkdir -p /var/www/html

# Remove old WordPress files if they exist
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removing old WordPress installation..."
rm -rf /var/www/html/wordpress

# Define the WordPress version (branch, tag, or commit)
GIT_COMMIT="main"  # Replace with a specific commit or tag if needed

# Clone the WordPress repository
git clone --depth=1 --branch "$GIT_COMMIT" https://github.com/hetmanskyi-cloud/wordpress.git /var/www/html/wordpress || { 
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to clone WordPress repository!"; exit 1; 
}

# Set proper ownership and permissions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting file permissions..."
chown -R www-data:www-data /var/www/html/wordpress
chmod -R 755 /var/www/html/wordpress

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress installation completed successfully!"

# 7. Configure WordPress (wp-config.php) for DB, ALB, Redis
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring WordPress..."

# Ensure WordPress directory exists, if not, re-download WordPress
if [ ! -d "/var/www/html" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: WordPress directory /var/www/html not found! Re-downloading WordPress..."
    mkdir -p /var/www/html
    cd /tmp
    curl -O https://wordpress.org/latest.zip
    unzip -q latest.zip
    mv wordpress/* /var/www/html/
    rm -rf wordpress latest.zip
fi

# Ensure /var/www/html/ exists before proceeding
cd /var/www/html || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Cannot access /var/www/html!"; exit 1; }

# Ensure wp-config-sample.php exists, if not, download it again
if [ ! -f "wp-config-sample.php" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: wp-config-sample.php not found! Downloading..."
    curl -O https://raw.githubusercontent.com/WordPress/WordPress/master/wp-config-sample.php
fi

# Ensure wp-config.php exists before modifying it
if [ ! -f "wp-config.php" ]; then
    cp wp-config-sample.php wp-config.php
fi

# Update wp-config.php with database and other configuration
sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
sed -i "s/username_here/${DB_USERNAME}/" wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" wp-config.php
sed -i "s/localhost/${DB_HOST}/" wp-config.php

# Append additional WordPress configurations
cat >> wp-config.php <<EOF

/* ALB and HTTPS Support */
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
define('WP_HOME', 'http://${AWS_LB_DNS}');
define('WP_SITEURL', 'http://${AWS_LB_DNS}');

/* WordPress Updates Configuration */
define('WP_AUTO_UPDATE_CORE', false);
define('AUTOMATIC_UPDATER_DISABLED', true);

/* Redis Configuration */
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT});
define('WP_REDIS_DATABASE', 0);
define('WP_CACHE', true);
define('WP_REDIS_SCHEME', 'tls');

/* Security Keys - these should be unique for each installation */
defined('AUTH_KEY') or define('AUTH_KEY', '$(openssl rand -base64 48)');
defined('SECURE_AUTH_KEY') or define('SECURE_AUTH_KEY', '$(openssl rand -base64 48)');
defined('LOGGED_IN_KEY') or define('LOGGED_IN_KEY', '$(openssl rand -base64 48)');
defined('NONCE_KEY') or define('NONCE_KEY', '$(openssl rand -base64 48)');
defined('AUTH_SALT') or define('AUTH_SALT', '$(openssl rand -base64 48)');
defined('SECURE_AUTH_SALT') or define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
defined('LOGGED_IN_SALT') or define('LOGGED_IN_SALT', '$(openssl rand -base64 48)');
defined('NONCE_SALT') or define('NONCE_SALT', '$(openssl rand -base64 48)');
EOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress configuration completed successfully!"

# 8. Set correct file permissions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting WordPress file permissions..."
chown -R www-data:www-data /var/www/html/wordpress
find /var/www/html/wordpress -type d -exec chmod 755 {} \;
find /var/www/html/wordpress -type f -exec chmod 644 {} \;

# 9. Install WP-CLI and run initial WordPress setup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# --- WP-CLI Cache Setup ---
mkdir -p /tmp/wp-cli-cache
export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running WordPress core installation..."
cd /var/www/html/wordpress
sudo -u www-data wp core install \
  --url="http://${AWS_LB_DNS}" \
  --title="${WP_TITLE}" \
  --admin_user="${WP_ADMIN}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --skip-email

# 10. Configure and enable Redis Object Cache
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Redis Object Cache..."
sudo -u www-data wp plugin install redis-cache --activate  # Install and activate Redis Object Cache plugin
sudo -u www-data wp redis enable || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to enable Redis caching."; exit 1; }  # Enable Redis caching in WordPress

# 11. Safe system update and cleanup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Performing safe system update..."
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --only-upgrade
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends
# Remove unused packages only if they are no longer needed
apt-get autoremove -y --purge
# Clean package cache to free up space
apt-get clean
echo "[$(date '+%Y-%m-%d %H:%M:%S')] System update and cleanup completed successfully!"

# 12. Create ALB health check endpoint using provided content
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating ALB health check endpoint..."
if [ -n "${HEALTHCHECK_CONTENT_B64}" ]; then
  echo "${HEALTHCHECK_CONTENT_B64}" | base64 --decode | sudo tee /var/www/html/wordpress/healthcheck.php > /dev/null
else
  echo "<?php http_response_code(200); ?>" | sudo tee /var/www/html/wordpress/healthcheck.php > /dev/null
fi
sudo chown www-data:www-data /var/www/html/wordpress/healthcheck.php
sudo chmod 644 /var/www/html/wordpress/healthcheck.php

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALB health check endpoint created successfully!"