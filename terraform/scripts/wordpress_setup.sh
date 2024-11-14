#!/bin/bash

# --- Log file setup --- #
LOG_FILE="/var/log/wordpress_install.log"
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"
exec > >(sudo tee -a "$LOG_FILE") 2>&1

echo "Starting WordPress installation..."

# --- System update and required packages installation --- #
echo "Updating system and installing required packages..."
sudo apt-get update && sudo apt-get upgrade -y && sleep 2
sudo apt-get install -y nginx mysql-client php-fpm php-mysql php-xml php-mbstring php-curl unzip || {
  echo "Package installation failed. Please check the connection and package availability."
  exit 1
}

# Clean up unneeded packages and cache
echo "Cleaning up unused packages and cache..."
sudo apt-get autoremove -y
sudo apt-get clean

# --- Download and install WordPress --- #
echo "Downloading and installing WordPress..."
cd /tmp || exit
curl -O https://wordpress.org/latest.zip
unzip -o latest.zip || { echo "Failed to unzip WordPress package."; exit 1; }

# Remove old WordPress directory if it exists
sudo rm -rf /var/www/html/wordpress
sudo mv wordpress /var/www/html/wordpress
rm latest.zip

# Set permissions for WordPress directory
sudo chown -R www-data:www-data /var/www/html/wordpress
sudo chmod -R 750 /var/www/html/wordpress

# Copy default WordPress config
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php || { echo "Failed to copy WordPress config file."; exit 1; }

# Environment variables for database connection
DB_NAME="${DB_NAME:-mydatabase}"
DB_USER="${DB_USER:-admin}"
DB_PASSWORD="${DB_PASSWORD:-examplepassword}"
DB_HOST="${DB_HOST:-$db_host}"

# Configure wp-config.php for database connection
echo "Configuring wp-config.php for database connection..."
sudo sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/username_here/$DB_USER/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/password_here/$DB_PASSWORD/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/localhost/$DB_HOST/" /var/www/html/wordpress/wp-config.php

# Set secure permissions for wp-config.php
sudo chmod 640 /var/www/html/wordpress/wp-config.php

# --- Configure Nginx for WordPress --- #
echo "Configuring Nginx for WordPress..."

# Remove default configuration if exists to avoid conflicts
if [[ -f /etc/nginx/sites-enabled/default ]]; then
  echo "Removing default Nginx configuration to prevent duplicate server error..."
  sudo rm /etc/nginx/sites-enabled/default
fi

# Create WordPress-specific Nginx configuration
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
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# Enable Nginx configuration and restart service
echo "Enabling Nginx configuration and restarting the service..."
sudo ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
if sudo nginx -t; then
  sudo systemctl restart nginx
else
  echo "Failed to restart Nginx. Check configuration."
  exit 1
fi

# --- Enable Nginx and PHP-FPM to start on boot --- #
echo "Enabling Nginx and PHP-FPM to start on boot..."
sudo systemctl enable --now nginx
if systemctl list-units --full -all | grep -q 'php8.1-fpm.service'; then
  sudo systemctl enable --now php8.1-fpm
else
  echo "php8.1-fpm service not found. Please verify PHP version."
fi

# --- Configure UFW Firewall (if enabled) --- #
if sudo ufw status | grep -qw "active"; then
  echo "Configuring UFW firewall for Nginx..."
  sudo ufw allow 'Nginx Full'
fi

# --- Final Check --- #
echo "Checking Nginx status..."
curl -I localhost || echo "Nginx may not be running. Please check the configuration."

echo "WordPress installation and configuration complete."
