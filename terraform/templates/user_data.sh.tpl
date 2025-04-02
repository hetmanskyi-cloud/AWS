#!/bin/bash

set -euxo pipefail  # Fail fast: exit on error, undefined variables, or pipeline failure; print each command

# Unified logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Redirect all logs to /var/log/user-data.log and console
# This ensures that both logs and errors are saved to a log file and displayed in the console.
exec 1> >(tee -a /var/log/user-data.log| tee /dev/tty) 2>&1
log "Starting user-data script..."

# Prepare temporary workspace and ensure the directory exists
log "Creating temporary directory for setup..."
export WP_TMP_DIR="/tmp/wordpress-setup"
mkdir -p "$WP_TMP_DIR"
echo "export WP_TMP_DIR='${WP_TMP_DIR}'" | sudo tee -a /etc/environment > /dev/null

# Define WordPress installation path and ensure the directory exists
log "Defining WordPress installation path..."
export WP_PATH="/var/www/html"
sudo mkdir -p "$WP_PATH"
echo "export WP_PATH='${WP_PATH}'" | sudo tee -a /etc/environment > /dev/null

# --- 1. Ensure AWS CLI (v2) is installed, if not already --- #

# This step checks if AWS CLI is installed and installs it if necessary.
if ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2..."

  # Check for package manager and install dependencies
  if command -v yum >/dev/null 2>&1; then
    yum install -y unzip curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip curl
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip curl
  else
    log "ERROR: Unknown package manager. Cannot install dependencies for AWS CLI."
    exit 1
  fi

  # Download and install AWS CLI
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${WP_TMP_DIR}/awscliv2.zip"
  unzip -q "${WP_TMP_DIR}/awscliv2.zip" -d "${WP_TMP_DIR}"
  sudo "${WP_TMP_DIR}/aws/install" --update
else
  log "AWS CLI is already installed."
fi

# --- 2. Export WordPress-related environment variables --- #

# This section exports environment variables for WordPress to be used in the deployment script.
# Note: Only non-sensitive variables are exported here. Secret variables (e.g., database credentials)
#       are fetched by the deploy_wordpress.sh script from AWS Secrets Manager.
log "Exporting environment variables..."
{
  # Export DB, Redis, and WordPress related configuration values
  echo "export DB_HOST='${wp_config.DB_HOST}'"
  echo "export DB_PORT='${wp_config.DB_PORT}'"  
  echo "export WP_TITLE='${wp_config.WP_TITLE}'"
  echo "export PHP_VERSION='${wp_config.PHP_VERSION}'"
  echo "export PHP_FPM_SERVICE='php${wp_config.PHP_VERSION}-fpm'"
  echo "export REDIS_HOST='${wp_config.REDIS_HOST}'"
  echo "export REDIS_PORT='${wp_config.REDIS_PORT}'"
  echo "export AWS_LB_DNS='${wp_config.AWS_LB_DNS}'"
  
  # Export other necessary environment variables
  echo "export SECRET_NAME='${wordpress_secrets_name}'"
  echo "export REDIS_AUTH_SECRET_NAME='${redis_auth_secret_name}'"
  echo "export HEALTHCHECK_CONTENT_B64='${healthcheck_content_b64}'"
  echo "export AWS_DEFAULT_REGION='${aws_region}'"

  # Export retry configuration variables
  echo "export RETRY_MAX_RETRIES='${retry_max_retries}'"
  echo "export RETRY_RETRY_INTERVAL='${retry_retry_interval}'"  
} | sudo tee -a /etc/environment > /dev/null

# Loads the newly exported environment variables to make them available for the session.
log "Loading environment variables..."
source /etc/environment
log "Exported environment variables:"
env | grep -E 'DB_|WP_|REDIS_|PHP|AWS'  # Debugging step to check environment variables

# --- 3. Download Amazon RDS root SSL certificate --- #

# This certificate is required to establish SSL connections to RDS when require_secure_transport=ON
# Reference: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html

log "Downloading RDS SSL certificate..."
curl -s https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o "$WP_TMP_DIR/rds-combined-ca-bundle.pem"

# Ensure it's readable by all processes (e.g., PHP, MySQL CLI)
chmod 644 "$WP_TMP_DIR/rds-combined-ca-bundle.pem"

# Validate certificate was downloaded
if [ ! -s "$WP_TMP_DIR/rds-combined-ca-bundle.pem" ]; then
  log "ERROR: Failed to download RDS SSL certificate!"
  exit 1
else
  log "RDS SSL certificate downloaded successfully."
fi

# --- 4. Retrieve or embed the WordPress deployment script --- #

# This step either downloads the WordPress deployment script from S3 or embeds it directly.
%{ if enable_s3_script }
  log "Downloading script from S3: ${wordpress_script_path}"
  aws s3 cp "${wordpress_script_path}" "$WP_TMP_DIR/deploy_wordpress.sh" --region ${aws_region}
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to download script from S3: ${wordpress_script_path}"
    exit 1
  else
    log "deploy_wordpress.sh downloaded successfully."
  fi

# Embed the WordPress local deployment script
%{ else }
  log "Embedding local script into $WP_TMP_DIR/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > "$WP_TMP_DIR/deploy_wordpress.sh"
${script_content}
END_SCRIPT
  log "Local deploy_wordpress.sh embedded successfully."
%{ endif }

# --- 5. Create a temporary simple healthcheck file (placeholder) for WordPress --- #

log "Creating temporary healthcheck file in $WP_PATH..."
echo "<?php http_response_code(200); ?>" | sudo tee "$WP_PATH/healthcheck.php" > /dev/null

# Verify that the healthcheck file was created successfully
if [ -f "$WP_PATH/healthcheck.php" ]; then
  log "Healthcheck file created successfully."
else
  log "ERROR: Failed to create healthcheck file."
  exit 1
fi

# --- 6. Execute the deployment script --- #

chmod +x "$WP_TMP_DIR/deploy_wordpress.sh"
log "Running $WP_TMP_DIR/deploy_wordpress.sh..."
"$WP_TMP_DIR/deploy_wordpress.sh"

# Final message indicating the script has completed
log "User-data script completed!"