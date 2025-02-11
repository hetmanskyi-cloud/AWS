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

# Export healthcheck content
cat <<'EOF' > /tmp/healthcheck_content.txt
${healthcheck_content}
EOF
export HEALTHCHECK_CONTENT="$(cat /tmp/healthcheck_content.txt)"

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
# 1. AWS CLI v2 is installed if not already present, using the official zip-based
#    installation method recommended by AWS.
# 2. If 'enable_s3_script' is true, the WordPress deployment script is downloaded
#    from an S3 bucket; otherwise, the local script content is embedded directly.
# 3. Environment variables (e.g. DB_HOST, WP_TITLE, etc.) are exported before
#    executing the deployment script.
# 4. The HEALTHCHECK_CONTENT variable is exported, containing the contents of the
#    chosen healthcheck file (either healthcheck-1.0.php or healthcheck-2.0.php)
#    read from the scripts directory. This variable is used by the deployment
#    script to create the ALB health check endpoint.
# 5. All logs are written to /var/log/user-data.log.
# 6. Ensure that your AMI can install 'unzip' and 'curl' using the appropriate
#    package manager (yum, dnf, or apt-get).
# -----------------------------------------------------------------------------