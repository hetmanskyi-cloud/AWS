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
sudo apt-get install -y nginx mysql-client php-fpm php-mysql php-xml php-mbstring php-curl unzip || {
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
curl -O https://wordpress.org/latest.zip
unzip -o latest.zip || { echo "Failed to unzip WordPress package."; exit 1; }

sudo rm -rf /var/www/html/wordpress
sudo mv wordpress /var/www/html/wordpress
rm latest.zip

sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php || { echo "Failed to copy WordPress config file."; exit 1; }

# --- Database configuration passed from Terraform --- #
# RDS credentials are passed via environment variables for simplicity.
# Consider using AWS Secrets Manager or another secure method for production environments.
DB_NAME="$${DB_NAME}"
DB_USERNAME="$${DB_USERNAME}"
DB_PASSWORD="$${DB_PASSWORD}"
DB_HOST="$${DB_HOST}"

# --- Check RDS availability --- #
echo "Checking RDS availability at host $DB_HOST..."
mysqladmin -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" ping > /dev/null 2>&1 || {
  echo "RDS is not reachable. Please check the network configuration or RDS status."
  exit 1
}

echo "Successfully connected to RDS at $DB_HOST" >> "$LOG_FILE"

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
    listen 80 default_server;         # Listen on port 80 for HTTP traffic
    server_name _;                    # Use default server name (any hostname)

    root /var/www/html/wordpress;     # Set WordPress as the root directory
    index index.php index.html index.htm; # Default files to serve

    location / {
        try_files \$uri \$uri/ /index.php?\$args; # Redirect all requests to WordPress
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;    # Include FastCGI configuration
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock; # Pass PHP requests to PHP-FPM
    }

    location ~ /\.ht {               # Deny access to .ht* files for security
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
# Perform a system upgrade to ensure all packages are up-to-date and secure.
# This step is placed at the end to avoid breaking dependencies during installation.
echo "Upgrading system and applying final updates..."
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get clean

# --- Optional reboot for updates to take effect --- #
# Optional: Reboot the server to apply all updates.
# This step may not be necessary depending on the updates installed.
echo "Rebooting the server to apply updates..."
sudo reboot
