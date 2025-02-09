#!/bin/bash
set -e

# Redirect all logs to /var/log/user-data.log and console
exec 1> >(tee -a /var/log/user-data.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting user-data script..."

# -----------------------------------------------------------------------------
# 1) Ensure AWS CLI (v2) is installed, if not already
# -----------------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing AWS CLI v2..."

  # Install 'unzip' and 'curl' if not present
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

  # Download AWS CLI v2 zip archive
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip

  # Install (or update) AWS CLI
  sudo ./aws/install --update

else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AWS CLI is already installed."
fi

# -----------------------------------------------------------------------------
# 2) Export WordPress-related environment variables
# -----------------------------------------------------------------------------
%{ for key, value in wp_config }
export ${key}="${value}"
%{ endfor }

# Export AWS region for Secrets Manager
export AWS_DEFAULT_REGION="${aws_region}"

# -----------------------------------------------------------------------------
# 3) Retrieve or embed the WordPress deployment script
# -----------------------------------------------------------------------------
%{ if enable_s3_script }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading script from S3: ${wordpress_script_path}"
  aws s3 cp "${wordpress_script_path}" /tmp/deploy_wordpress.sh
%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local script into /tmp/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > /tmp/deploy_wordpress.sh
${script_content}
END_SCRIPT
%{ endif }

# -----------------------------------------------------------------------------
# 4) Execute the deployment script
# -----------------------------------------------------------------------------
chmod +x /tmp/deploy_wordpress.sh
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running /tmp/deploy_wordpress.sh..."
/tmp/deploy_wordpress.sh

echo "[$(date '+%Y-%m-%d %H:%M:%S')] User-data script completed!"

# -----------------------------------------------------------------------------
# Notes:
# 1. We install AWS CLI v2 if not already present. We use the official zip-based
#    installation method recommended by AWS documentation.
# 2. If 'enable_s3_script' is true, we download the WordPress deployment script
#    from an S3 bucket.
# 3. Otherwise, we embed the script content directly in user_data.
# 4. We set environment variables (DB_HOST, WP_TITLE, etc.) before running the script.
# 5. Logs are written to /var/log/user-data.log.
# 6. Make sure your AMI can install 'unzip' and 'curl' (via yum/dnf/apt-get) successfully.
# -----------------------------------------------------------------------------