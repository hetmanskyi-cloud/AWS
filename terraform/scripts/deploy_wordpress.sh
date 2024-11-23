#!/bin/bash

# --- Log file setup --- #
LOG_FILE="/var/log/wordpress_install.log"
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"
exec > >(sudo tee -a "$LOG_FILE") 2>&1

echo "Starting WordPress installation..."

# --- System update (without upgrade at this stage) --- #
echo "Updating system repositories..."
sudo apt-get update && sleep 2

# --- Install required packages --- #
echo "Installing required packages..."
sudo apt-get install -y nginx mysql-client php-fpm php-mysql php-xml php-mbstring php-curl unzip build-essential tcl libssl-dev || {
  echo "Package installation failed. Please check the connection and package availability."
  exit 1
}

# PHP Version passed from Terraform
PHP_VERSION="$${PHP_VERSION}"

# Ensure PHP-FPM is installed and enabled
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"

if ! systemctl list-units --full -all | grep -q "${PHP_FPM_SERVICE}"; then
  echo "Installing PHP-FPM for PHP version (${PHP_VERSION})..."
  sudo apt-get install -y "${PHP_FPM_SERVICE}" || { echo "Failed to install PHP-FPM."; exit 1; }
fi

sudo systemctl enable --now "${PHP_FPM_SERVICE}"

# --- Clean up unneeded packages and cache --- #
echo "Cleaning up unused packages and cache..."
sudo apt-get autoremove -y
sudo apt-get clean

# --- Download and install WordPress --- #
echo "Downloading and installing WordPress..."
cd /tmp || exit
curl -O https://wordpress.org/latest.zip || { echo "Failed to download WordPress package."; exit 1; }
unzip -o latest.zip || { echo "Failed to unzip WordPress package."; exit 1; }

sudo rm -rf /var/www/html/wordpress
sudo mv wordpress /var/www/html/wordpress
rm latest.zip

sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php || { echo "Failed to copy WordPress config file."; exit 1; }

# --- Database configuration passed from Terraform --- #
DB_NAME="$${DB_NAME}"
DB_USERNAME="$${DB_USERNAME}"
DB_PASSWORD="$${DB_PASSWORD}"
DB_HOST="$${DB_HOST}"

# --- Configure wp-config.php --- #
echo "Configuring wp-config.php..."
sudo sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/username_here/${DB_USERNAME}/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/localhost/${DB_HOST}/" /var/www/html/wordpress/wp-config.php

# --- Set permissions for WordPress files --- #
echo "Setting permissions for WordPress files..."
sudo chown -R www-data:www-data /var/www/html/wordpress
sudo chmod -R 750 /var/www/html/wordpress
sudo chmod 640 /var/www/html/wordpress/wp-config.php

# --- Install Redis CLI with TLS support --- #
echo "Installing Redis CLI with TLS support..."
(
  cd /tmp || exit
  wget http://download.redis.io/releases/redis-7.1.0.tar.gz || { echo "Failed to download Redis source."; exit 1; }
  tar xzf redis-7.1.0.tar.gz
  cd redis-7.1.0 || exit
  make BUILD_TLS=yes || { echo "Failed to compile Redis CLI with TLS support."; exit 1; }
  sudo cp src/redis-cli /usr/local/bin/
) || exit

rm -rf /tmp/redis-7.1.0 /tmp/redis-7.1.0.tar.gz

# --- Install WP-CLI --- #
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || { echo "Failed to download WP-CLI."; exit 1; }
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# --- Configure WordPress to use Redis with TLS --- #
echo "Configuring WordPress to use Redis with TLS..."
cd /var/www/html/wordpress || exit
# Ensure wp-cli runs as www-data
sudo -u www-data wp plugin install redis-cache --activate || { echo "Failed to install Redis Cache plugin."; exit 1; }

# Redis configuration passed from Terraform
REDIS_HOST="$${REDIS_HOST}"
REDIS_PORT="$${REDIS_PORT}"

# Update wp-config.php for Redis
echo "Adding Redis configuration to wp-config.php..."
sudo tee -a /var/www/html/wordpress/wp-config.php > /dev/null <<EOL

// Redis configuration
define( 'WP_REDIS_HOST', '${REDIS_HOST}' );
define( 'WP_REDIS_PORT', ${REDIS_PORT} );
define( 'WP_REDIS_SCHEME', 'tls' );
EOL

# Add WP_CACHE constant to enable caching
echo "Enabling WordPress caching..."
sudo sed -i "/^<?php/a define('WP_CACHE', true);" /var/www/html/wordpress/wp-config.php || { echo "Failed to enable WP_CACHE."; exit 1; }

# Enable Redis object cache
sudo -u www-data wp redis enable || { echo "Failed to enable Redis cache."; exit 1; }

# --- Restart services to apply changes --- #
echo "Restarting PHP and Nginx services..."
sudo systemctl restart "${PHP_FPM_SERVICE}"
sudo systemctl restart nginx

# --- Configure Nginx for WordPress --- #
echo "Configuring Nginx for WordPress..."

if [[ -f /etc/nginx/sites-enabled/default ]]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

sudo tee /etc/nginx/sites-available/wordpress > /dev/null <<EOL
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html/wordpress;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

sudo ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo systemctl restart nginx || { echo "Failed to restart Nginx."; exit 1; }

sudo systemctl enable nginx

# --- Configure UFW firewall if active --- #
if sudo ufw status | grep -qw "active"; then
  echo "Configuring UFW firewall for Nginx..."
  sudo ufw allow 'Nginx Full'
fi

# --- Upgrade system and apply final updates --- #
echo "Upgrading system and applying final updates..."
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get clean

echo "WordPress installation and configuration completed successfully."
