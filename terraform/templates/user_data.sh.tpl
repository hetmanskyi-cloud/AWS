#!/bin/bash
set -e

# Redirect all logs to /var/log/user-data.log and console
exec 1> >(tee -a /var/log/user-data.log| tee /dev/tty) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting user-data script..."

# 1. Ensure AWS CLI (v2) is installed, if not already
if ! command -v aws >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing AWS CLI v2..."
  
  if command -v yum >/dev/null 2>&1; then
    yum install -y unzip curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip curl
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y unzip curl
  else
    echo "[ERROR] Unknown package manager. Cannot install dependencies for AWS CLI."
    exit 1
  fi

  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install --update
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AWS CLI is already installed."
fi

# 2. Export WordPress-related environment variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exporting environment variables..."
{
%{ for key, value in wp_config }
  echo "export ${key}=\"${value}\""
%{ endfor }
  echo "export SECRET_ARN='${wordpress_secrets_arn}'"
  echo "export HEALTHCHECK_CONTENT_B64='${healthcheck_content_b64}'"
  echo "export AWS_DEFAULT_REGION=\"${aws_region}\""
} | sudo tee -a /etc/environment > /dev/null

# 3. Reload environment variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading environment variables..."
source /etc/environment
env | grep DB_  # Debugging step

# 4. Retrieve or embed the WordPress deployment script
%{ if enable_s3_script }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading script from S3: ${wordpress_script_path}"
  aws s3 cp "${wordpress_script_path}" /tmp/deploy_wordpress.sh --region ${aws_region}
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to download script from S3: ${wordpress_script_path}"
    exit 1
  fi
%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local script into /tmp/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > /tmp/deploy_wordpress.sh
${script_content}
END_SCRIPT
%{ endif }

# 4.1 Retrieve or embed the healthcheck file
%{ if enable_s3_script }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading healthcheck file from S3: ${healthcheck_s3_path}"
  aws s3 cp "${healthcheck_s3_path}" /var/www/html/wordpress/healthcheck.php --region ${aws_region}
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to download healthcheck file from S3: ${healthcheck_s3_path}"
    exit 1
  fi
%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local healthcheck content..."
  echo "${healthcheck_content_b64}" | base64 --decode > /var/www/html/wordpress/healthcheck.php
%{ endif }

# 5. Execute the deployment script
chmod +x /tmp/deploy_wordpress.sh
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running /tmp/deploy_wordpress.sh..."
/tmp/deploy_wordpress.sh

echo "[$(date '+%Y-%m-%d %H:%M:%S')] User-data script completed!"