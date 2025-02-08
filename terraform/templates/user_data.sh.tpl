#!/bin/bash
set -e

# Redirect all logs to /var/log/user-data.log and console
exec 1> >(tee -a /var/log/user-data.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting user-data script..."

# Ensure AWS CLI is installed (for Secrets Manager or S3 access), unless already present
if ! command -v aws >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing awscli..."
  if command -v yum >/dev/null 2>&1; then
    yum install -y awscli
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y awscli
  else
    echo "[ERROR] Unable to install awscli. Unknown package manager."
    exit 1
  fi
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] awscli is already installed."
fi

# Export WordPress configuration variables
%{ for key, value in wp_config }
export ${key}="${value}"
%{ endfor }

# Export AWS region for Secrets Manager
export AWS_DEFAULT_REGION="${aws_region}"

# Decide how to get the WordPress deployment script
%{ if enable_s3_script }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading script from S3: ${wordpress_script_path}"
  aws s3 cp "${wordpress_script_path}" /tmp/deploy_wordpress.sh
%{ else }
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Embedding local script into /tmp/deploy_wordpress.sh..."
  cat <<'END_SCRIPT' > /tmp/deploy_wordpress.sh
${script_content}
END_SCRIPT
%{ endif }

# Make the script executable and run it
chmod +x /tmp/deploy_wordpress.sh
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running /tmp/deploy_wordpress.sh..."
/tmp/deploy_wordpress.sh

echo "[$(date '+%Y-%m-%d %H:%M:%S')] User-data script completed!"

# Notes:
# 1. AWS CLI is installed here if not already present (for both Secrets Manager and S3 usage).
# 2. If 'enable_s3_script' is true, the WordPress deployment script is downloaded from S3.
# 3. If 'enable_s3_script' is false, the script content is embedded directly via user_data.
# 4. WordPress environment variables and AWS region are exported before running the script.
# 5. Ensure that your AMI or package manager (yum/apt-get) is available for installing awscli if needed.