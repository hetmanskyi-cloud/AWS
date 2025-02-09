#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# Redirect all stdout and stderr to /var/log/wordpress_install.log as well as console
exec 1> >(tee -a /var/log/wordpress_install.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting WordPress installation..."

# -----------------------------------------------------------------------------
# 1. Install base packages needed for WordPress, minus curl/unzip
#    (which are installed in user_data.sh.tpl).
#
#    - jq: for JSON parsing
#    - netcat-openbsd (nc): for checking DB connectivity
#    - Others: python3, etc., if needed
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing base packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  jq \
  netcat-openbsd

# -----------------------------------------------------------------------------
# 2. Wait for MySQL (RDS) to become available (up to 60 seconds)
#    - This helps avoid race conditions if the DB is not fully ready.
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking if MySQL is ready on host: ${DB_HOST}..."
for i in {1..12}; do
  if nc -z "${DB_HOST}" 3306; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL is reachable!"
    break
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL not ready yet. Waiting 5 seconds..."
  sleep 5
done

# Final check after loop
if ! nc -z "${DB_HOST}" 3306; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: MySQL not available after 60s. Exiting."
  exit 1
fi

# -----------------------------------------------------------------------------
# 3. Retrieve secrets from AWS Secrets Manager
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Retrieving secrets from AWS Secrets Manager..."
SECRETS=$(aws secretsmanager get-secret-value --secret-id "${SECRET_NAME}" --query 'SecretString' --output text)

# Verify secrets retrieval
if [ -z "$SECRETS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

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

# -----------------------------------------------------------------------------
# 4. Install WordPress dependencies (Nginx, PHP, MySQL client, etc.)
#    - curl/unzip are removed here, as they're installed in user_data.tpl
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 5. Configure Nginx (renaming '$https' to '$forwarded_https')
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring Nginx..."
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    root /var/www/html/wordpress;
    index index.php;
    server_name _;

    # ALB Support
    set_real_ip_from 10.0.0.0/16;
    real_ip_header X-Forwarded-For;

    # SSL configuration for ALB
    set \$forwarded_https off;
    if (\$http_x_forwarded_proto = "https") {
        set \$forwarded_https on;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        # Pass ALB headers to PHP
        fastcgi_param HTTPS \$forwarded_https;
        fastcgi_param HTTP_X_FORWARDED_PROTO \$http_x_forwarded_proto;
    }
}
EOF

# Enable WordPress site and disable the default site
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# -----------------------------------------------------------------------------
# 6. Download and install WordPress
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading and installing WordPress..."
cd /tmp
curl -O https://wordpress.org/latest.zip
unzip -q latest.zip
rm -rf /var/www/html/wordpress
mv wordpress /var/www/html/wordpress
rm latest.zip

# -----------------------------------------------------------------------------
# 7. Configure WordPress (wp-config.php) for DB, ALB, Redis
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring WordPress..."
cd /var/www/html/wordpress
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USERNAME/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php
sed -i "s/localhost/$DB_HOST/" wp-config.php

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

# -----------------------------------------------------------------------------
# 8. Set correct file permissions
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting WordPress file permissions..."
chown -R www-data:www-data /var/www/html/wordpress
find /var/www/html/wordpress -type d -exec chmod 755 {} \;
find /var/www/html/wordpress -type f -exec chmod 644 {} \;

# -----------------------------------------------------------------------------
# 9. Install WP-CLI and run initial WordPress setup
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running WordPress core installation..."
cd /var/www/html/wordpress
sudo -u www-data wp core install \
  --url="http://${AWS_LB_DNS}" \
  --title="${WP_TITLE}" \
  --admin_user="${WP_ADMIN}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${WP_ADMIN_EMAIL}" \
  --skip-email

# -----------------------------------------------------------------------------
# 10. Configure and enable Redis Object Cache
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Redis Object Cache..."
sudo -u www-data wp plugin install redis-cache --activate  # Install and activate Redis Object Cache plugin
sudo -u www-data wp redis enable  # Enable Redis caching in WordPress

# -----------------------------------------------------------------------------
# 11. System upgrade and cleanup
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating system packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y  # Upgrade installed packages
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y  # Perform a full distribution upgrade
apt-get autoremove -y  # Remove unnecessary packages
apt-get clean  # Clean up package cache to free disk space

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress installation and system update completed successfully!"

# -----------------------------------------------------------------------------
# 12. Create health check endpoint for ALB
# -----------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating ALB health check endpoint..."
echo "<?php http_response_code(200); ?>" | sudo tee /var/www/html/wordpress/healthcheck.php > /dev/null  # Create a simple health check file
sudo chown www-data:www-data /var/www/html/wordpress/healthcheck.php  # Set correct ownership
sudo chmod 644 /var/www/html/wordpress/healthcheck.php  # Set correct permissions

# -----------------------------------------------------------------------------
# Notes:
#  - This script expects the following environment variables:
#      SECRET_NAME, DB_HOST, AWS_LB_DNS, WP_TITLE, WP_ADMIN, WP_ADMIN_PASSWORD,
#      WP_ADMIN_EMAIL, REDIS_HOST, REDIS_PORT, PHP_VERSION, etc.
#  - A wait-loop ensures that MySQL (RDS) is available before installation.
#  - AWS Secrets Manager is used for credentials, requiring AWS CLI to be installed.
#  - Logs are written to /var/log/wordpress_install.log (via 'tee').
#  - WP-CLI is installed at /usr/local/bin/wp.
#  - Redis Object Cache plugin is installed and enabled for performance improvements.
#  - A simple health check endpoint (healthcheck.php) is created for ALB monitoring.
#  - If using Amazon Linux 2023 or a different distro, replace 'apt-get' with 'yum' or 'dnf'.
# -----------------------------------------------------------------------------