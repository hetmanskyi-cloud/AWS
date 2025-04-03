#!/bin/bash

# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u),
# and fail if any command in a pipeline fails (-o pipefail)
set -euo pipefail

# --- Description --- #
# This script runs a full diagnostic on a WordPress EC2 instance.
# It can be executed remotely via SSM to check system resources, services, database, Redis, and ALB status.

# --- Optional: Automatic SSM session if executed locally --- #
if [[ "${1:-}" == "--ssm" ]]; then
  INSTANCE_NAME="${2:-dev-asg-instance}"
  REGION="${3:-eu-west-1}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SSM session to instance: $INSTANCE_NAME (Region: $REGION)"

  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -z "$INSTANCE_ID" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No running instance found with tag Name=$INSTANCE_NAME"
    exit 1
  fi

  aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
    --document-name "AWS-StartInteractiveCommand" \
    --parameters 'command=["bash -s"]' < "$0"

  exit 0
fi

# --- Script Metadata --- #
SCRIPT_VERSION="1.0.0"
CURL_TIMEOUT=10
MYSQL_TIMEOUT=5
PING_TIMEOUT=5
DIG_TIMEOUT=5

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
echo "=== Server Status Check (version $SCRIPT_VERSION) $TIMESTAMP ==="

# --- Instance Metadata --- #
INSTANCE_ID=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-id || echo "UNKNOWN")
echo "Instance ID: $INSTANCE_ID"
AZ=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "N/A")
INSTANCE_TYPE=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/instance-type || echo "N/A")
PUBLIC_IP=$(curl -s --max-time "$CURL_TIMEOUT" http://169.254.169.254/latest/meta-data/public-ipv4 || echo "N/A")
echo "Availability Zone: $AZ"
echo "Instance Type: $INSTANCE_TYPE"
echo "Public IP: $PUBLIC_IP"

# --- System Resources Check --- #
echo "Checking system resources..."
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEMORY_USED=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

echo "CPU Usage: $CPU_USAGE%"
echo "Memory Usage: $MEMORY_USED%"
echo "Disk Usage: $DISK_USAGE%"

[[ "${CPU_USAGE%.*}" -gt 80 ]] && echo "WARNING: High CPU usage detected"
[[ "${MEMORY_USED%.*}" -gt 80 ]] && echo "WARNING: High memory usage detected"
[[ "${DISK_USAGE%.*}" -gt 80 ]] && echo "WARNING: High disk usage detected"

# --- Nginx and PHP-FPM Status --- #
echo "Checking Nginx and PHP-FPM status..."
systemctl is-active --quiet nginx && echo "Nginx is running" || echo "ERROR: Nginx is NOT running"

PHP_FPM_VERSION=$(php -v | grep -oP '^PHP \K[0-9]+\.[0-9]+' | head -n1)
PHP_FPM_SERVICE="php${PHP_FPM_VERSION}-fpm"
systemctl is-active --quiet "$PHP_FPM_SERVICE" && echo "PHP-FPM ($PHP_FPM_VERSION) is running" || echo "ERROR: PHP-FPM ($PHP_FPM_VERSION) is NOT running"

# --- Database Connection Check --- #
echo "Checking database connection..."
WP_CONFIG="/var/www/html/wordpress/wp-config.php"

if [[ -f "$WP_CONFIG" ]]; then
  DB_HOST=$(grep "DB_HOST" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_USER=$(grep "DB_USER" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
  DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

  if [[ -n "$DB_HOST" ]]; then
    echo "Checking DNS for DB Host..."
    dig +short "$DB_HOST" &>/dev/null && echo "DB Host DNS resolved: $DB_HOST" || echo "ERROR: DB Host DNS resolution failed"

    echo "Pinging DB Host..."
    ping -c 3 -W "$PING_TIMEOUT" "$DB_HOST" &>/dev/null && echo "Ping to DB Host successful" || echo "ERROR: Ping to DB Host failed"

    echo "Checking MySQL port 3306..."
    if timeout "$MYSQL_TIMEOUT" nc -zv "$DB_HOST" 3306 &>/dev/null; then
      echo "MySQL port 3306 is open"
      if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" --ssl-mode=REQUIRED "$DB_NAME" -e "SELECT 1" &>/dev/null; then
        echo "Database TLS connection successful"
      else
        echo "ERROR: Database TLS connection failed"
      fi
    else
      echo "ERROR: MySQL port 3306 is not accessible"
    fi
  else
    echo "ERROR: Failed to parse DB credentials from wp-config.php"
  fi
else
  echo "ERROR: wp-config.php not found at $WP_CONFIG"
fi

# --- WordPress Config Check --- #
echo "Checking WordPress installation..."
[[ -f "$WP_CONFIG" ]] && echo "WordPress configuration exists" || echo "ERROR: WordPress configuration missing"

echo "Checking WP_SITEURL..."
SITE_URL=$(grep "WP_SITEURL" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g")
[[ -n "$SITE_URL" ]] && echo "WP_SITEURL found: $SITE_URL" || echo "WARNING: WP_SITEURL not defined"

# --- Nginx Config Validation --- #
echo "Validating Nginx configuration..."
NGINX_TEST=$(nginx -t 2>&1)
echo "$NGINX_TEST" | grep -q "successful" && echo "Nginx configuration is valid" || echo "ERROR: Nginx configuration is INVALID"

# --- Redis Connection Check --- #
echo "Checking Redis connection..."
REDIS_HOST=$(grep "REDIS_HOST" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)
REDIS_PORT=$(grep "REDIS_PORT" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

if [[ -n "$REDIS_HOST" && -n "$REDIS_PORT" ]]; then
  if timeout "$MYSQL_TIMEOUT" nc -zv "$REDIS_HOST" "$REDIS_PORT" &>/dev/null; then
    echo "Redis TCP connection OK at $REDIS_HOST:$REDIS_PORT"
    if command -v redis-cli &>/dev/null; then
      redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping | grep -q PONG && echo "Redis PING successful" || echo "ERROR: Redis PING failed"
    fi
  else
    echo "ERROR: Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
  fi
else
  echo "WARNING: Redis connection details missing"
fi

# --- ALB Check --- #
echo "Checking ALB (Application Load Balancer)..."
ALB_DNS=$(grep "ALB_DNS" "$WP_CONFIG" | grep -o "'.*'" | sed "s/'//g" | xargs)

if [[ -n "$ALB_DNS" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "http://$ALB_DNS")
  [[ "$HTTP_STATUS" -eq 200 ]] && echo "ALB is reachable (HTTP 200)" || echo "ALB reachable but returned HTTP $HTTP_STATUS"
else
  echo "WARNING: ALB DNS not found, skipping check"
fi

echo "Server diagnostic completed at $(date)"