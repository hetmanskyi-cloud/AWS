#!/bin/bash

# --- User-Data Script for WordPress Stage/Prod Environment (Golden AMI) --- #
# This script configures secrets and runtime settings for a pre-built WordPress golden image.
# It does NOT install WordPress, Nginx, PHP, WP-CLI, or dependencies (already present in AMI).

set -euxo pipefail  # Fail on error, unset variables, log commands

# Unified logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Redirect all logs to both file and console for diagnostics
exec 1> >(tee -a /var/log/user-data.log | tee /dev/tty) 2>&1
log "Starting user-data script..."

# --- 1. Export WordPress-related environment variables --- #

# This section exports environment variables for WordPress to be used in runtime config.
# Note: Only non-sensitive variables are exported here. Secrets are fetched by the script from AWS Secrets Manager.
log "Exporting environment variables..."
{
  echo "DB_HOST=\"${wp_config.DB_HOST}\""
  echo "DB_PORT=\"${wp_config.DB_PORT}\""
  echo "WP_TITLE=\"${wp_config.WP_TITLE}\"" # Used for auto-install if triggered; safe to export always
  echo "PHP_VERSION=\"${wp_config.PHP_VERSION}\""
  echo "PHP_FPM_SERVICE=\"${wp_config.PHP_FPM_SERVICE}\""
  echo "REDIS_HOST=\"${wp_config.REDIS_HOST}\""
  echo "REDIS_PORT=\"${wp_config.REDIS_PORT}\""
  echo "AWS_LB_DNS=\"${wp_config.AWS_LB_DNS}\""
  
  # Export other necessary environment variables
  echo "SECRET_NAME=\"${wordpress_secrets_name}\""
  echo "REDIS_AUTH_SECRET_NAME=\"${redis_auth_secret_name}\""
  echo "AWS_DEFAULT_REGION=\"${aws_region}\""

  # Retry configuration for operations such as healthcheck, package installs, etc.
  echo "RETRY_MAX_RETRIES=\"${retry_max_retries}\""
  echo "RETRY_RETRY_INTERVAL=\"${retry_retry_interval}\""
  echo "enable_cloudwatch_logs=\"${enable_cloudwatch_logs}\""

  # CloudWatch log group names
  echo "CLOUDWATCH_USER_DATA_LOG_GROUP_NAME=\"${cloudwatch_log_groups["user_data"]}\""
  echo "CLOUDWATCH_SYSTEM_LOG_GROUP_NAME=\"${cloudwatch_log_groups["system"]}\""
  echo "CLOUDWATCH_NGINX_LOG_GROUP_NAME=\"${cloudwatch_log_groups["nginx"]}\""
  echo "CLOUDWATCH_PHP_FPM_LOG_GROUP_NAME=\"${cloudwatch_log_groups["php_fpm"]}\""
  echo "CLOUDWATCH_WORDPRESS_LOG_GROUP_NAME=\"${cloudwatch_log_groups["wordpress"]}\""

} | sudo tee -a /etc/environment > /dev/null

log "Loading environment variables..."
source /etc/environment

# Optional debug: print all environment variables (sorted) to the user-data log for troubleshooting.
log "Sorted environment variables for debugging:"
env | sort >> /var/log/user-data.log

# --- 2. Load Environment Variables --- #

# All non-sensitive config vars are passed via /etc/environment by Terraform user_data.
log "Loading environment variables..."
set -a
source /etc/environment
set +a

# --- 3. Retrieve secrets from AWS Secrets Manager --- #

log "Retrieving secrets from AWS Secrets Manager..."
SECRETS=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${wordpress_secrets_name}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$SECRETS" ]; then
  log "ERROR: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

log "Secrets retrieved successfully."

# Export secrets for WordPress configuration
export DB_NAME=$(echo "$SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$SECRETS" | jq -r '.DB_PASSWORD')

export WP_ADMIN=$(echo "$SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$SECRETS" | jq -r '.ADMIN_PASSWORD')

# Export WordPress security keys and salts
export AUTH_KEY=$(echo "$SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$SECRETS" | jq -r '.NONCE_SALT')

# Retrieve Redis AUTH token from AWS Secrets Manager
log "Retrieving Redis AUTH token from AWS Secrets Manager..."
REDIS_AUTH_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${redis_auth_secret_name}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$REDIS_AUTH_SECRETS" ]; then
  log "ERROR: Failed to retrieve Redis AUTH secret from AWS Secrets Manager"
  exit 1
fi

log "Redis AUTH secret retrieved successfully."
  
# Export Redis AUTH token for WordPress configuration
export REDIS_AUTH_TOKEN=$(echo "$REDIS_AUTH_SECRETS" | jq -r '.REDIS_AUTH_TOKEN')

# Write critical secrets to /etc/environment for use in healthcheck
echo "DB_NAME=\"$DB_NAME\"" | sudo tee -a /etc/environment
echo "DB_USER=\"$DB_USER\"" | sudo tee -a /etc/environment
echo "DB_PASSWORD=\"$DB_PASSWORD\"" | sudo tee -a /etc/environment
echo "REDIS_AUTH_TOKEN=\"$REDIS_AUTH_TOKEN\"" | sudo tee -a /etc/environment

log "All secrets successfully retrieved and exported."

# --- 4. Download Amazon RDS root SSL certificate --- #

# This certificate is required to establish SSL connections to RDS when require_secure_transport=ON
# Reference: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html

log "Downloading RDS SSL certificate..."
curl -s https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /etc/ssl/certs/rds-combined-ca-bundle.pem

# Ensure it's readable by all processes (e.g., PHP, MySQL CLI)
chmod 644 /etc/ssl/certs/rds-combined-ca-bundle.pem

# Validate certificate was downloaded
if [ ! -s /etc/ssl/certs/rds-combined-ca-bundle.pem ]; then
  log "ERROR: Failed to download RDS SSL certificate!"
  exit 1
else
  log "RDS SSL certificate downloaded successfully."
fi

# --- 5. Regenerate wp-config.php for current environment --- #

log "Updating wp-config.php for new environment using WP-CLI..."

WP_PATH="/var/www/html"
WP_CLI_BIN="/usr/local/bin/wp"
PHP_FPM_SERVICE="php${wp_config.PHP_VERSION}-fpm"

# Update DB credentials and salts in wp-config.php via WP-CLI (as www-data)
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set DB_NAME "$DB_NAME" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set DB_USER "$DB_USER" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set DB_PASSWORD "$DB_PASSWORD" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set DB_HOST "$DB_HOST" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set DB_PORT "$DB_PORT" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set AUTH_KEY "$AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set SECURE_AUTH_KEY "$SECURE_AUTH_KEY" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set LOGGED_IN_KEY "$LOGGED_IN_KEY" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set NONCE_KEY "$NONCE_KEY" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set AUTH_SALT "$AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set SECURE_AUTH_SALT "$SECURE_AUTH_SALT" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set LOGGED_IN_SALT "$LOGGED_IN_SALT" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set NONCE_SALT "$NONCE_SALT" --path="$WP_PATH"

# Redis connection config
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_REDIS_HOST "$REDIS_HOST" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_REDIS_PORT "$REDIS_PORT" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_REDIS_PASSWORD "$REDIS_AUTH_TOKEN" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_REDIS_CLIENT "predis" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_REDIS_SCHEME "tls" --path="$WP_PATH"

# Set URLs for current environment (ALB)
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_SITEURL "http://$AWS_LB_DNS" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_HOME "http://$AWS_LB_DNS" --path="$WP_PATH"

# Optional: Debug logging
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG true --raw --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG_LOG "/var/log/wordpress.log" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG_DISPLAY false --raw --path="$WP_PATH"

log "wp-config.php successfully updated for stage environment."

# --- 6. WordPress Automated Install (if DB is empty) --- #
if ! sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" core is-installed --path="$WP_PATH"; then
  log "Running WordPress auto-install for new environment..."
  sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" core install \
    --url="http://$AWS_LB_DNS" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --path="$WP_PATH" \
    || { log "ERROR: WordPress install failed!"; exit 1; }
  log "WordPress installed automatically by user-data script."
else
  log "WordPress already installed in DB, skipping wp core install."
fi

# --- 7. Restart services for config reload --- #

log "Restarting services for new configuration..."
systemctl restart nginx || log "WARNING: nginx restart failed"
systemctl restart "$PHP_FPM_SERVICE" || log "WARNING: PHP-FPM restart failed"

# --- 8. Reload CloudWatch Agent config if enabled --- #

if [ "${enable_cloudwatch_logs}" = "true" ]; then
  log "Reloading CloudWatch Agent configuration..."
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
fi

# --- 9. Healthcheck Endpoint (log presence) --- #

if [ -f "/var/www/html/healthcheck.php" ]; then
  log "healthcheck.php present."
else
  log "WARNING: healthcheck.php not found!"
fi

# --- 10. Check and Fix Permissions --- #

log "Checking/fixing permissions for WordPress directory..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# --- 11. Debug Environment & Secure Cleanup --- #

log "Printing environment variables for debugging:"
env | sort >> /var/log/user-data.log

# Remove only sensitive variables from /etc/environment
log "Clearing sensitive secrets from /etc/environment..."
sudo sed -i '/^DB_PASSWORD=/d' /etc/environment
sudo sed -i '/^REDIS_AUTH_TOKEN=/d' /etc/environment
log "Sensitive secrets removed from /etc/environment."

# --- 12. Success --- #

log "User-data script for WordPress completed successfully."

# --- Notes --- #
# - No installation of software (baked into AMI).
# - Only config/secrets update, healthcheck, and service restarts.
# - Logs all actions to /var/log/user-data.log.
# - Secrets are never hardcoded in AMI — always retrieved fresh from Secrets Manager.
# - For troubleshooting, tail logs or check CloudWatch (if enabled).