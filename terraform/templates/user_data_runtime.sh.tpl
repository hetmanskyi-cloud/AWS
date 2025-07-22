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

# Define WordPress installation path from Terraform variable
log "Defining WordPress installation path..."
export WP_PATH="${WP_PATH}"
echo "export WP_PATH='${WP_PATH}'" | sudo tee -a /etc/environment > /dev/null

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

  # Export Public site URL and enable HTTPS
  echo "PUBLIC_SITE_URL=\"${public_site_url}\""
  echo "ENABLE_HTTPS=\"${enable_https}\""

  # Export other necessary environment variables
  echo "WP_SECRETS_NAME=\"${wordpress_secrets_name}\""
  echo "RDS_SECRETS_NAME=\"${rds_secrets_name}\""
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

# Retrieve WordPress Secrets
log "Retrieving WordPress secrets from AWS Secrets Manager..."
WP_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${wordpress_secrets_name}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$WP_SECRETS" ]; then
  log "ERROR: Failed to retrieve WordPress secrets from AWS Secrets Manager"
  exit 1
fi

log "WordPress secrets retrieved successfully."

# Retrieve RDS Database Secrets
log "Retrieving RDS database secrets from AWS Secrets Manager..."
RDS_SECRETS=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${rds_secrets_name}" \
  --query 'SecretString' \
  --output text)

# Verify secrets retrieval
if [ -z "$RDS_SECRETS" ]; then
  log "ERROR: Failed to retrieve RDS database secrets from AWS Secrets Manager"
  exit 1
fi

log "All RDS database secrets retrieved successfully."

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

# --- Export secrets for WordPress configuration --- #

# Export WordPress admin credentials from the correct source ($WP_SECRETS)
export WP_ADMIN=$(echo "$WP_SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$WP_SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$WP_SECRETS" | jq -r '.ADMIN_PASSWORD')

# Export WordPress security keys and salts from the correct source ($WP_SECRETS)
export AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$WP_SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$WP_SECRETS" | jq -r '.NONCE_SALT')

# Export RDS secrets from the correct source ($RDS_SECRETS)
export DB_NAME=$(echo "$RDS_SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$RDS_SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$RDS_SECRETS" | jq -r '.DB_PASSWORD')

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

# --- 5. Mount EFS File System via Access Point --- #

log "Starting EFS setup..."
# We check for both IDs, as the access point is useless without the file system.
if [ -n "${efs_file_system_id}" ] && [ -n "${efs_access_point_id}" ]; then
  log "EFS File System ID found: ${efs_file_system_id}"
  log "EFS Access Point ID found: ${efs_access_point_id}"

  # Check if the EFS mount helper is already installed to make this script idempotent.
  if ! command -v mount.efs >/dev/null 2>&1; then
    log "Installing amazon-efs-utils from source..."

    # Update package lists and install all dependencies required to build from source.
    sudo apt-get update -y
    sudo apt-get install -y \
      git \
      binutils \
      make \
      automake \
      autoconf \
      libtool \
      pkg-config \
      libssl-dev \
      cargo \
      ca-certificates \
      python3-pip \
      python3-botocore \
      gettext

    # Clone the official aws/efs-utils repository from GitHub.
    git clone https://github.com/aws/efs-utils /tmp/efs-utils
    cd /tmp/efs-utils

    # CRITICAL: Set this environment variable to bypass the PEP 668 check in Ubuntu 24.04.
    export PIP_BREAK_SYSTEM_PACKAGES=1

    # Run the build script to compile the source code into a .deb package.
    ./build-deb.sh

    # Install the locally built .deb package. 'apt' is used to handle other dependencies like stunnel.
    sudo apt-get -y install ./build/amazon-efs-utils*deb

    # Return to a known directory and clean up the temporary source files.
    cd /
    rm -rf /tmp/efs-utils

    log "amazon-efs-utils installed successfully from source."
  else
    log "amazon-efs-utils already installed."
  fi

  # Define and create the specific mount point for uploads.
  # The base WP_PATH /var/www/html is on the local EBS disk.
  export EFS_UPLOADS_PATH="$WP_PATH/wp-content/uploads"
  log "Ensuring EFS mount point ${EFS_UPLOADS_PATH} exists..."
  sudo mkdir -p "$EFS_UPLOADS_PATH"
  log "Mount point created."

  # Define the entry for /etc/fstab.
  # We now mount to the specific uploads directory.
  EFS_FSTAB_ENTRY="${efs_file_system_id} ${EFS_UPLOADS_PATH} efs _netdev,tls,accesspoint=${efs_access_point_id} 0 0"

  # Add the mount entry to fstab only if it doesn't already exist.
  if ! grep -qF -- "$EFS_FSTAB_ENTRY" /etc/fstab; then
    log "Adding EFS mount to /etc/fstab..."
    echo "$EFS_FSTAB_ENTRY" | sudo tee -a /etc/fstab
  else
    log "EFS mount already present in /etc/fstab."
  fi

  # Mount all filesystems of type 'efs' defined in fstab.
  log "Mounting all EFS filesystems..."
  sudo mount -a -t efs

  # Verify that EFS is mounted correctly and set permissions on the mount point directory.
  if mount | grep -q "${EFS_UPLOADS_PATH}"; then
    log "EFS successfully mounted to ${EFS_UPLOADS_PATH} via Access Point."
    # Set permissions on the mount point AFTER it's mounted.
    sudo chown www-data:www-data "${EFS_UPLOADS_PATH}"
    sudo chmod 775 "${EFS_UPLOADS_PATH}"
  else
    log "ERROR: Failed to mount EFS to ${EFS_UPLOADS_PATH}."
    exit 1
  fi
else
  log "EFS IDs not provided, skipping EFS mount."
fi

# --- 6. Regenerate wp-config.php for current environment --- #

log "Updating wp-config.php for new environment using WP-CLI..."

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

# Set URLs for current environment
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_SITEURL "$PUBLIC_SITE_URL" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_HOME "$PUBLIC_SITE_URL" --path="$WP_PATH"

# Optional: Debug logging
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG true --raw --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG_LOG "/var/log/wordpress.log" --path="$WP_PATH"
sudo -u www-data HOME=/tmp php "$WP_CLI_BIN" config set WP_DEBUG_DISPLAY false --raw --path="$WP_PATH"

log "wp-config.php successfully updated for stage environment."

# --- 7. WordPress Automated Install (if DB is empty) --- #
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

# --- 8. Restart services for config reload --- #

log "Restarting services for new configuration..."
systemctl restart nginx || log "WARNING: nginx restart failed"
systemctl restart "$PHP_FPM_SERVICE" || log "WARNING: PHP-FPM restart failed"

# --- 9. Reload CloudWatch Agent config if enabled --- #

if [ "${enable_cloudwatch_logs}" = "true" ]; then
  log "Reloading CloudWatch Agent configuration..."
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
fi

# --- 10. Healthcheck Endpoint (log presence) --- #

if [ -f "/var/www/html/healthcheck.php" ]; then
  log "healthcheck.php present."
else
  log "WARNING: healthcheck.php not found!"
fi

# --- 11. Check and Fix Permissions --- #

log "Checking/fixing permissions for WordPress directory..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# --- 12. Debug Environment & Secure Cleanup --- #

log "Printing environment variables for debugging:"
env | sort >> /var/log/user-data.log

# Remove only sensitive variables from /etc/environment
log "Clearing sensitive secrets from /etc/environment..."
sudo sed -i '/^DB_PASSWORD=/d' /etc/environment
sudo sed -i '/^REDIS_AUTH_TOKEN=/d' /etc/environment
log "Sensitive secrets removed from /etc/environment."

log "User-data script for WordPress completed successfully."

# --- Notes --- #
# - No installation of software (baked into AMI).
# - Only config/secrets update, healthcheck, and service restarts.
# - Logs all actions to /var/log/user-data.log.
# - Secrets are never hardcoded in AMI — always retrieved fresh from Secrets Manager.
# - For troubleshooting, tail logs or check CloudWatch (if enabled).
