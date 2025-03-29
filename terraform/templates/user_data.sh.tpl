#!/bin/bash
set -e # Exit script if any command fails

# Ensure /var/log directory exists for the user_data script
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring /var/log directory exists..."
sudo mkdir -p /var/log

# Redirect all logs to /var/log/user-data.log and console
# This ensures that both logs and errors are saved to a log file and displayed in the console.
exec 1> >(tee -a /var/log/user-data.log| tee /dev/tty) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting user-data script..."

# 1. Ensure AWS CLI (v2) is installed, if not already
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
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AWS CLI is already installed."
fi

# 2. Export WordPress-related environment variables
# This section exports environment variables for WordPress to be used in the deployment script.
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exporting environment variables..."
{
  %{ for key, value in wp_config }
    if [[ "${key}" != "DB_USER" && "${key}" != "DB_PASSWORD" ]]; then
      echo "export ${key}=\"${value}\""
    fi
  %{ endfor }
  echo "export SECRET_NAME='${wordpress_secrets_name}'"
  echo "export HEALTHCHECK_CONTENT_B64='${healthcheck_content_b64}'"
  echo "export AWS_DEFAULT_REGION=\"${aws_region}\""
  echo "# Set HOME directory for www-data user when running wp-cli commands"
  echo "alias wp='sudo -u www-data HOME=/tmp wp'"
} | sudo tee -a /etc/environment > /dev/null

# 3. Reload environment variables
# Loads the newly exported environment variables to make them available for the session.
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading environment variables..."
source /etc/environment
env | grep DB_  # Debugging step to check environment variables

# 4. Retrieve or embed the WordPress deployment script
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

# 4.1 Download wp-config-template.php from S3 to /tmp/
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading wp-config-template.php from S3..."
  aws s3 cp "${wp_config_template_path}" /tmp/wp-config-template.php --region ${aws_region}
  if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to download wp-config-template.php!"
    exit 1
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] wp-config-template.php downloaded successfully."
  fi

%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local script into /tmp/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > /tmp/deploy_wordpress.sh
${script_content}
END_SCRIPT
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Local deploy_wordpress.sh embedded successfully."
%{ endif }

# 5. Ensure /var/www/html directory exists
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring /var/www/html directory exists..."
sudo mkdir -p /var/www/html

# 6. Create a temporary simple healthcheck file (placeholder) for WordPress
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating temporary healthcheck file..."
echo "<?php http_response_code(200); ?>" | sudo tee /var/www/html/healthcheck.php > /dev/null

# Verify that the healthcheck file was created successfully
if [ -f "/var/www/html/healthcheck.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Healthcheck file created successfully."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to create healthcheck file."
  exit 1
fi

# 7. Execute the deployment script
chmod +x /tmp/deploy_wordpress.sh
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running /tmp/deploy_wordpress.sh..."
/tmp/deploy_wordpress.sh

# Final message indicating the script has completed
echo "[$(date '+%Y-%m-%d %H:%M:%S')] User-data script completed!"