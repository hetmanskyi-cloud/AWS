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

# --- PHP Version passed from Terraform --- #
PHP_VERSION="${PHP_VERSION}"

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
DB_NAME="${DB_NAME}"
DB_USERNAME="${DB_USERNAME}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"

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

# --- Install WP-CLI --- #
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || { echo "Failed to download WP-CLI."; exit 1; }
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

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
  sudo ufw reload
fi

# --- Upgrade system and apply final updates --- #
echo "Upgrading system and applying final updates..."
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get clean

echo "WordPress installation and configuration completed successfully."
