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
    log "Running apt-get update before installing AWS CLI dependencies..."
    sudo apt-get update -q || { log "ERROR: apt-get update failed"; exit 1; }
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip curl
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
  echo "DB_HOST=\"${wp_config.DB_HOST}\""
  echo "DB_PORT=\"${wp_config.DB_PORT}\""  
  echo "WP_TITLE=\"${wp_config.WP_TITLE}\""
  echo "PHP_VERSION=\"${wp_config.PHP_VERSION}\""
  echo "PHP_FPM_SERVICE=\"php${wp_config.PHP_VERSION}-fpm\""
  echo "REDIS_HOST=\"${wp_config.REDIS_HOST}\""
  echo "REDIS_PORT=\"${wp_config.REDIS_PORT}\""
  echo "AWS_LB_DNS=\"${wp_config.AWS_LB_DNS}\""
  
  # Export other necessary environment variables
  echo "SECRET_NAME=\"${wordpress_secrets_name}\""
  echo "REDIS_AUTH_SECRET_NAME=\"${redis_auth_secret_name}\""
  echo "HEALTHCHECK_S3_PATH=\"${healthcheck_s3_path}\""
  echo "AWS_DEFAULT_REGION=\"${aws_region}\""

  # Retry configuration for operations such as healthcheck, package installs, etc.
  echo "RETRY_MAX_RETRIES=\"${retry_max_retries}\""
  echo "RETRY_RETRY_INTERVAL=\"${retry_retry_interval}\""
} | sudo tee -a /etc/environment > /dev/null

# Loads the newly exported environment variables to make them available for the session.
log "Loading environment variables..."
source /etc/environment

# Optional debug: print all environment variables (sorted) to the user-data log for troubleshooting.
log "Sorted environment variables for debugging:"
env | sort >> /var/log/user-data.log

# --- 3. Download Amazon RDS root SSL certificate --- #

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

# --- 4. Install and start CloudWatch Agent for log forwarding --- #

if [ "${enable_cloudwatch_logs}" = "true" ]; then
  log "Installing CloudWatch Agent..."

# Install CloudWatch Agent package
curl -s https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -o /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Confirm successful installation
  if command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then
    log "CloudWatch Agent installed successfully."
  else
    log "CloudWatch Agent installation failed."
    exit 1
  fi

# Create config directory
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
chown -R root:root /opt/aws/amazon-cloudwatch-agent/etc/
chmod -R 755 /opt/aws/amazon-cloudwatch-agent/etc/

# Write config to /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${cloudwatch_log_groups.user_data}",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/var/log/wordpress_install.log",
            "log_group_name": "${cloudwatch_log_groups.user_data}",
            "log_stream_name": "{instance_id}-install",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/var/log/cloudwatch-agent-status.log",
            "log_group_name": "${cloudwatch_log_groups.user_data}",
            "log_stream_name": "{instance_id}-cw-status",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/var/log/cloudwatch-agent-validate.log",
            "log_group_name": "${cloudwatch_log_groups.user_data}",
            "log_stream_name": "{instance_id}-cw-validate",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${cloudwatch_log_groups.system}",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%b %d %H:%M:%S"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "${cloudwatch_log_groups.nginx}",
            "log_stream_name": "{instance_id}-access"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "${cloudwatch_log_groups.nginx}",
            "log_stream_name": "{instance_id}-error"
          },
          {
            "file_path": "/var/log/php${wp_config.PHP_VERSION}-fpm.log",
            "log_group_name": "${cloudwatch_log_groups.php_fpm}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/wordpress.log",
            "log_group_name": "${cloudwatch_log_groups.wordpress}",
            "log_stream_name": "{instance_id}"
          }          
        ]
      }
    },
    "log_stream_name": "default-stream",
    "force_flush_interval": 15
  }
}
EOF

log "CloudWatch Agent config written successfully."

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

log "CloudWatch Agent started."

log "Validating CloudWatch Agent status and configuration..."

# Check CloudWatch Agent status and write output to log
log "Checking CloudWatch Agent status..."
STATUS_OUTPUT=$(/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status)
echo "$STATUS_OUTPUT" | tee /var/log/cloudwatch-agent-status.log

if echo "$STATUS_OUTPUT" | grep -q '"status": "running"'; then
  log "CloudWatch Agent is running and configured successfully."
else
  log "CloudWatch Agent failed to start. Check /var/log/cloudwatch-agent-status.log for details."
fi
fi

# --- 5. Retrieve the WordPress deployment script --- #

# Download deployment script file from S3
log "Downloading deployment script from S3: ${wordpress_script_path}"
aws s3 cp "${wordpress_script_path}" "$WP_TMP_DIR/deploy_wordpress.sh" --region ${aws_region}
if [ $? -ne 0 ]; then
  log "ERROR: Failed to download script from S3: ${wordpress_script_path}"
  exit 1
else
  log "deploy_wordpress.sh downloaded successfully."
fi

# --- 6. Create a temporary simple healthcheck file (placeholder) for WordPress --- #

log "Creating temporary healthcheck file in $WP_PATH..."
echo "<?php http_response_code(200); ?>" | sudo tee "$WP_PATH/healthcheck.php" > /dev/null
log "Temporary healthcheck.php created successfully."

# Verify that the healthcheck file was created successfully
if [ -f "$WP_PATH/healthcheck.php" ]; then
  log "Healthcheck file created successfully."
else
  log "ERROR: Failed to create healthcheck file."
  exit 1
fi

# --- 7. Execute the deployment script --- #

chmod +x "$WP_TMP_DIR/deploy_wordpress.sh"
log "Running $WP_TMP_DIR/deploy_wordpress.sh..."
"$WP_TMP_DIR/deploy_wordpress.sh"

# Final message indicating the script has completed
log "User-data script completed!"

# --- Notes --- #
# - This user_data script is rendered from a Terraform template and executed on first boot of the EC2 instance.
# - Due to AWS EC2's 16 KB user_data size limit, we store the full WordPress deployment script (`deploy_wordpress.sh`) in an S3 bucket and download it at runtime.
# - The script performs the following:
#   * Prepares the environment and export directories for WordPress installation.
#   * Installs AWS CLI and CloudWatch Agent (if not already present).
#   * Downloads the Amazon RDS root SSL certificate for secure DB connections.
#   * Exports necessary non-sensitive environment variables (DB config, Redis, ALB DNS).
#   * Loads environment configuration from Terraform and makes it available to all processes.
#   * Starts CloudWatch Agent (if enabled), forwarding logs from Nginx, PHP-FPM, user-data, system, and WordPress to predefined CloudWatch Log Groups.
#   * Downloads the actual WordPress installation script from S3.
#   * Creates a temporary healthcheck endpoint to ensure ALB detects the instance as healthy.
#   * Executes the downloaded script (`deploy_wordpress.sh`) which installs and configures WordPress.
# - All logs are streamed to both the console and `/var/log/user-data.log`, and forwarded to CloudWatch Logs (if enabled).
# - Secrets (e.g., database and Redis credentials) are **not exposed** in this file and are fetched securely inside `deploy_wordpress.sh` via AWS Secrets Manager.
# - Designed for scalable, secure, and modular WordPress deployments in EC2 Auto Scaling environments.