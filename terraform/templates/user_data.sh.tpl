#!/bin/bash
set -euxo pipefail  # Fail fast: exit on error, undefined variables, or pipeline failure; print each command

# Ensure /var/log directory exists for the user_data script
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring /var/log directory exists..."
sudo mkdir -p /var/log

# Redirect all logs to /var/log/user-data.log and console
# This ensures that both logs and errors are saved to a log file and displayed in the console.
exec 1> >(tee -a /var/log/user-data.log| tee /dev/tty) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting user-data script..."

# --- 1. Ensure AWS CLI (v2) is installed, if not already --- #

# This step checks if AWS CLI is installed and installs it if necessary.
if ! command -v aws >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing AWS CLI v2..."
  
  # Check for package manager and install dependencies
  if command -v yum >/dev/null 2>&1; then
    yum install -y unzip curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip curl
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y unzip curl
  else
    echo "[ERROR] Unknown package manager. Cannot install dependencies for AWS CLI."
    exit 1
  fi

  # Download and install AWS CLI
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install --update
  rm -f awscliv2.zip
  rm -rf aws
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AWS CLI is already installed."
fi

# --- 2. Export WordPress-related environment variables --- #

# This section exports environment variables for WordPress to be used in the deployment script.
# Note: Only non-sensitive variables are exported here. Secret variables (e.g., database credentials)
#       are fetched by the deploy_wordpress.sh script from AWS Secrets Manager.
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exporting environment variables..."
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
  echo "export HEALTHCHECK_CONTENT_B64='${healthcheck_content_b64}'"
  echo "export AWS_DEFAULT_REGION='${aws_region}'"

  # Export retry configuration variables
  echo "export RETRY_MAX_RETRIES='${retry_max_retries}'"
  echo "export RETRY_RETRY_INTERVAL='${retry_retry_interval}'"
  
  # Set HOME directory for wp-cli commands
  echo "alias wp='sudo -u www-data HOME=/tmp wp'"
} | sudo tee -a /etc/environment > /dev/null

# --- 3. Reload environment variables --- #

# Loads the newly exported environment variables to make them available for the session.
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading environment variables..."
source /etc/environment
env | grep DB_  # Debugging step to check environment variables

# --- 4. Download Amazon RDS root SSL certificate --- #

# This certificate is required to establish SSL connections to RDS when require_secure_transport=ON
# Reference: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading RDS SSL certificate..."
curl -s https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /tmp/rds-combined-ca-bundle.pem

# Ensure it's readable by all processes (e.g., PHP, MySQL CLI)
chmod 644 /tmp/rds-combined-ca-bundle.pem

# Validate certificate was downloaded
if [ ! -s /tmp/rds-combined-ca-bundle.pem ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to download RDS SSL certificate!"
  exit 1
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] RDS SSL certificate downloaded successfully."
fi

# --- 5. Retrieve or embed the WordPress deployment script --- #

# This step either downloads the WordPress deployment script from S3 or embeds it directly.
%{ if enable_s3_script }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading script from S3: ${wordpress_script_path}"
  aws s3 cp "${wordpress_script_path}" /tmp/deploy_wordpress.sh --region ${aws_region}
  if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to download script from S3: ${wordpress_script_path}"
    exit 1
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] deploy_wordpress.sh downloaded successfully."
  fi

# Embed the WordPress local deployment script
%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local script into /tmp/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > /tmp/deploy_wordpress.sh
${script_content}
END_SCRIPT
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Local deploy_wordpress.sh embedded successfully."
%{ endif }

# --- 6. Ensure /var/www/html directory exists --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring /var/www/html directory exists..."
sudo mkdir -p /var/www/html

# --- 7. Create a temporary simple healthcheck file (placeholder) for WordPress --- #

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating temporary healthcheck file..."
echo "<?php http_response_code(200); ?>" | sudo tee /var/www/html/healthcheck.php > /dev/null

# Verify that the healthcheck file was created successfully
if [ -f "/var/www/html/healthcheck.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Healthcheck file created successfully."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to create healthcheck file."
  exit 1
fi

# --- 8. Execute the deployment script --- #

chmod +x /tmp/deploy_wordpress.sh
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running /tmp/deploy_wordpress.sh..."
/tmp/deploy_wordpress.sh

# Final message indicating the script has completed
echo "[$(date '+%Y-%m-%d %H:%M:%S')] User-data script completed!"
# --- End of Script --- #