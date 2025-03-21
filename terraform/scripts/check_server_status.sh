#!/bin/bash

# --- Exit on any error --- #
set -e

# --- Script Version --- #
SCRIPT_VERSION="1.0.0"

# --- Timeout Settings --- #
CURL_TIMEOUT=10
MYSQL_TIMEOUT=5
PING_TIMEOUT=5
DIG_TIMEOUT=5

# --- Instance Metadata --- #
INSTANCE_ID=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-id || echo "UNKNOWN")
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

echo "=== 🖥 Server Status Check (version $SCRIPT_VERSION) $TIMESTAMP ==="
echo " Instance ID: $INSTANCE_ID"

AZ=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "N/A")
INSTANCE_TYPE=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-type || echo "N/A")
PUBLIC_IP=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/public-ipv4 || echo "N/A")

echo " 🔹 Instance Details:"
echo "  - Availability Zone: $AZ"
echo "  - Instance Type: $INSTANCE_TYPE"
echo "  - Public IP: $PUBLIC_IP"

# --- System Resources Check --- #
echo " 🔍 Checking system resources..."
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEMORY_USED=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

echo " 📊 Resource usage:"
echo "  - CPU: $CPU_USAGE%"
echo "  - Memory: $MEMORY_USED%"
echo "  - Disk: $DISK_USAGE%"

[[ "${CPU_USAGE%.*}" -gt 80 ]] && echo " ⚠️  High CPU usage detected!"
[[ "${MEMORY_USED%.*}" -gt 80 ]] && echo " ⚠️  High memory usage detected!"
[[ "${DISK_USAGE%.*}" -gt 80 ]] && echo " ⚠️  High disk usage detected!"

# --- Nginx and PHP-FPM Check --- #
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
  echo " ❌ PHP-FPM ($PHP_FPM_VERSION) is NOT running!"
fi

# --- Database Connection Check (TLS) --- #
echo " 🔍 Checking database connection with TLS..."
WP_CONFIG="/var/www/html/wordpress/wp-config.php"

if [[ -f "$WP_CONFIG" ]]; then
  DB_HOST=$(grep "DB_HOST" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_USER=$(grep "DB_USER" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

  if [[ -n "$DB_HOST" ]]; then
    echo "  - Checking DNS resolution for DB host..."
    if dig +short "$DB_HOST" &>/dev/null; then
      echo "  ✅ DNS resolution OK: $DB_HOST"
    else
      echo "  ❌ DNS resolution FAILED: $DB_HOST"
    fi

    echo "  - Checking VPC reachability (ping)..."
    if ping -c 3 -W "$PING_TIMEOUT" "$DB_HOST" &>/dev/null; then
      echo "  ✅ Ping to DB host successful"
    else
      echo "  ❌ Ping to DB host FAILED!"
    fi

    echo "  - Checking MySQL port (3306)..."
    if timeout "$MYSQL_TIMEOUT" nc -zv "$DB_HOST" 3306 &>/dev/null; then
      echo "  ✅ MySQL port 3306 is open"

      if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" --ssl-mode=REQUIRED "$DB_NAME" -e "SELECT 1" &>/dev/null; then
        echo "  ✅ Database connection over TLS successful"
        DB_SIZE=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" --ssl-mode=REQUIRED -e "
          SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1)
          FROM information_schema.tables
          WHERE table_schema = '$DB_NAME'
          GROUP BY table_schema;" 2>/dev/null)
        echo "   - Database Size: ${DB_SIZE:-N/A} MB"
      else
        echo "  ❌ Database TLS connection FAILED"
      fi
    else
      echo "  ❌ MySQL port 3306 is NOT accessible!"
    fi
  else
    echo "  ❌ Failed to extract DB credentials from wp-config.php"
  fi
else
  echo " ❌ WordPress config NOT found at $WP_CONFIG"
fi

# --- WordPress Installation Check --- #
echo " 🔍 Checking WordPress installation..."
if [[ -f "$WP_CONFIG" ]]; then
  echo " ✅ WordPress configuration found"
else
  echo " ❌ WordPress configuration NOT found!"
fi

# --- WordPress Site URL Check --- #
echo " 🔍 Checking WordPress Site URL..."
SITE_URL=$(grep "WP_SITEURL" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")
if [[ -n "$SITE_URL" ]]; then
  echo " ✅ WP_SITEURL found: $SITE_URL"
else
  echo " ⚠️ WP_SITEURL not defined in wp-config.php"
fi

# --- Nginx Configuration Validation --- #
echo " 🔍 Checking Nginx configuration..."
NGINX_TEST=$(nginx -t 2>&1)
if echo "$NGINX_TEST" | grep -q "successful"; then
  echo " ✅ Nginx configuration is valid"
else
  echo " ❌ Nginx configuration is INVALID!"
  echo "   $(echo "$NGINX_TEST" | grep -v 'nginx: ')"
fi

# --- Check ElastiCache (Redis) connection --- #
echo " 🔍 Checking Redis (ElastiCache) connection..."
REDIS_HOST=$(grep "REDIS_HOST" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
REDIS_PORT=$(grep "REDIS_PORT" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

if [[ -n "$REDIS_HOST" && -n "$REDIS_PORT" ]]; then
  if timeout "$MYSQL_TIMEOUT" nc -zv "$REDIS_HOST" "$REDIS_PORT" &>/dev/null; then
    echo " ✅ Redis TCP connection OK at $REDIS_HOST:$REDIS_PORT"

    # Optional Redis PING check
    if command -v redis-cli &>/dev/null; then
      if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping | grep -q PONG; then
        echo " ✅ Redis PING response: PONG"
      else
        echo " ❌ Redis PING failed!"
      fi
    fi
  else
    echo " ❌ Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
  fi
else
  echo " ⚠️ Redis connection details not found in wp-config.php"
fi

# --- Check ALB (Application Load Balancer) status --- #
echo " 🔍 Checking ALB (Application Load Balancer)..."
ALB_DNS=$(grep "ALB_DNS" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

if [[ -n "$ALB_DNS" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "http://$ALB_DNS")
  if [[ "$HTTP_STATUS" -eq 200 ]]; then
    echo " ✅ ALB is reachable and responds with HTTP 200"
  else
    echo " ❌ ALB is reachable but returned HTTP $HTTP_STATUS"
  fi
else
  echo " ⚠️ ALB DNS not found in wp-config.php, skipping ALB check"
fi

echo "✅ Server check completed at $(date)"