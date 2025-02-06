#!/bin/bash

# Exit on any error
set -e

# Timeout settings
CURL_TIMEOUT=10
MYSQL_TIMEOUT=5

# Get instance metadata
INSTANCE_ID=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-id || echo "UNKNOWN")
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

echo "=== 🖥 Server Status Check (version $SCRIPT_VERSION) $TIMESTAMP ==="
echo " Instance ID: $INSTANCE_ID"

AZ=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "N/A")
INSTANCE_TYPE=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-type || echo "N/A")
PUBLIC_IP=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/public-ipv4 || echo "N/A")

echo " 🔹 Instance Details:"
echo "   - Availability Zone: $AZ"
echo "   - Instance Type: $INSTANCE_TYPE"
echo "   - Public IP: $PUBLIC_IP"

# Check system resources with thresholds
echo " 🔍 Checking system resources..."
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEMORY_FREE=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

echo " 📊 Resource usage:"
echo "   - CPU: $CPU_USAGE%"
echo "   - Memory: $MEMORY_FREE%"
echo "   - Disk: $DISK_USAGE%"

# Alert on high resource usage
[ "${CPU_USAGE%.*}" -gt 80 ] && echo "⚠️  High CPU usage detected!"
[ "${MEMORY_FREE%.*}" -gt 80 ] && echo "⚠️  High memory usage detected!"
[ "${DISK_USAGE%.*}" -gt 80 ] && echo "⚠️  High disk usage detected!"

# Check Nginx and PHP-FPM
echo " 🔍 Checking Nginx and PHP-FPM status..."
if systemctl is-active --quiet nginx; then
    echo " ✅ Nginx is running"
else
    echo " ❌ Nginx is NOT running!"
fi

PHP_FPM_VERSION=$(php -v | grep -oP '^PHP \K[0-9]+\.[0-9]+' | head -n1)
PHP_FPM_SERVICE="php${PHP_FPM_VERSION}-fpm"

if systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
    echo " ✅ PHP-FPM ($PHP_FPM_VERSION) is running"
else
    echo " ❌ PHP-FPM is NOT running!"
fi

# Check database connection
echo " 🔍 Checking database connection..."
WP_CONFIG="/var/www/html/wordpress/wp-config.php"
if [[ -f "$WP_CONFIG" ]]; then
    # Extract database connection details from wp-config.php
    DB_HOST=$(grep "DB_HOST" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")
    DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")
    DB_USER=$(grep "DB_USER" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")
    DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")

    if [[ -n "$DB_HOST" ]]; then
        if nc -z -w "$MYSQL_TIMEOUT" "$DB_HOST" 3306; then
            echo " ✅ Database port is accessible"
            # Try to connect to database
            if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" &>/dev/null; then
                echo " ✅ Database connection successful"
                # Get database size
                DB_SIZE=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "
                    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1)
                    FROM information_schema.tables
                    WHERE table_schema = '$DB_NAME'
                    GROUP BY table_schema;" 2>/dev/null)
                echo "   - Database Size: ${DB_SIZE:-N/A} MB"
            else
                echo " ❌ Database connection failed"
            fi
        else
            echo " ❌ Database port is not accessible!"
        fi
    else
        echo " ❌ Could not extract database credentials from wp-config.php"
    fi
else
    echo " ❌ WordPress config file not found at $WP_CONFIG"
fi

# Check WordPress installation
echo " 🔍 Checking WordPress installation..."
if [[ -f "/var/www/html/wordpress/wp-config.php" ]]; then
    echo " ✅ WordPress configuration found"
else
    echo " ❌ WordPress configuration NOT found!"
fi

echo " ✅ Check completed at $(date)"

# ===========================================
# NOTES
# ===========================================
#
# 📌 Purpose:
# This script performs comprehensive health checks on an AWS EC2 instance 
# running WordPress. It provides real-time insights into the server's 
# health, services, and configuration.
#
# 🛠 Features:
# - Checks CPU, Memory, and Disk usage.
# - Verifies Nginx and PHP-FPM services.
# - Confirms database connectivity.
# - Ensures WordPress installation integrity.
# - Outputs results directly to the console.
#
# 🔹 How to Use:
# 1️⃣ Copy the script to the instance:
#    ```bash
#    sudo cp check_server_status.sh /usr/local/bin/
#    ```
# 2️⃣ Set execution permissions:
#    ```bash
#    sudo chmod +x /usr/local/bin/check_server_status.sh
#    ```
# 3️⃣ Run the script:
#    ```bash
#    sudo /usr/local/bin/check_server_status.sh
#    ```
#
# 📊 Expected Output:
# ✅ CPU, Memory, and Disk usage stats.
# ✅ Running status of Nginx and PHP-FPM.
# ✅ Database connectivity check.
# ✅ WordPress installation verification.
#
# 🔴 Error Handling:
# If any service is down or misconfigured, the script will print ❌ warnings.
#
# 📝 Version History:
# - v1.0.0: Initial version.
# 
#
# ===========================================