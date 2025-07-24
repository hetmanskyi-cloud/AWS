#!/bin/bash

set -euxo pipefail # Fail fast: exit on error, undefined variables, print each command; pipeline failure

# --- Unified logging function --- #
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Redirect all output to a log file for debugging
exec 1> >(tee -a /var/log/user-data.log) 2>&1
log "Starting Ansible-based WordPress setup..."

# --- 1. Install AWS CLI v2 (Prerequisite for fetching secrets) --- #
# This is required before anything else, as we need it to pull secrets.
if ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2..."
  # Create a temporary directory for the download
  TMP_DIR="/tmp/awscli-setup"
  mkdir -p "$TMP_DIR"

  # Install dependencies for the installer
  apt-get update -y
  apt-get install -y unzip curl

  # Download and install AWS CLI
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMP_DIR/awscliv2.zip"
  unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"
  sudo "$TMP_DIR/aws/install" --update
  rm -rf "$TMP_DIR" # Clean up
else
  log "AWS CLI is already installed."
fi

# --- 2. Install Ansible and Git --- #
log "Installing Ansible & Git..."
apt-get install -y ansible git

# --- 3. Clone Ansible Playbooks Repository --- #
log "Cloning Ansible playbooks repository..."
# Using the correct URL for cloning the entire repository
git clone https://github.com/hetmanskyi-cloud/AWS.git /opt/ansible
# Change directory to the root of the cloned repo
cd /opt/ansible

# --- 4. Retrieve Secrets from AWS Secrets Manager --- #
log "Retrieving all secrets from AWS Secrets Manager to pass to Ansible..."

# Fetch WordPress Secrets (Admin, Salts, etc.)
WP_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${wordpress_secrets_name}" --query 'SecretString' --output text)
export WP_ADMIN_USER=$(echo "$WP_SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$WP_SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD=$(echo "$WP_SECRETS" | jq -r '.ADMIN_PASSWORD')
export AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$WP_SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$WP_SECRETS" | jq -r '.NONCE_SALT')

# Fetch RDS Secrets
RDS_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${rds_secrets_name}" --query 'SecretString' --output text)
export DB_NAME=$(echo "$RDS_SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$RDS_SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$RDS_SECRETS" | jq -r '.DB_PASSWORD')

# Fetch Redis Secret
REDIS_AUTH_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${redis_auth_secret_name}" --query 'SecretString' --output text)
export REDIS_AUTH_TOKEN=$(echo "$REDIS_AUTH_SECRETS" | jq -r '.REDIS_AUTH_TOKEN')

log "Secrets retrieved successfully."

# --- 5. Execute Ansible Playbook --- #
log "Executing install-wordpress.yml playbook..."

# Temporarily disable command printing (-x) to prevent secrets from being logged.
set +x

# Run the playbook locally, passing all variables from Terraform and Secrets Manager.
ansible-playbook -i localhost, -c local terraform/ansible/playbooks/install-wordpress.yml --extra-vars '
  # Complex variables passed from Terraform as JSON strings
  wp_config=${wp_config}
  cloudwatch_log_groups=${cloudwatch_log_groups}

  # Simple variables passed directly from Terraform
  wp_version=${wordpress_version}
  site_url=${public_site_url}
  enable_https=${enable_https}
  scripts_bucket_name=${scripts_bucket_name}
  efs_file_system_id=${efs_file_system_id}
  efs_access_point_id=${efs_access_point_id}
  enable_cloudwatch_logs=${enable_cloudwatch_logs}

  # Secret variables created in this script (escaped for Terraform)
  wp_admin_user='"$${WP_ADMIN_USER}"'
  wp_admin_password='"$${WP_ADMIN_PASSWORD}"'
  wp_admin_email='"$${WP_ADMIN_EMAIL}"'
  db_name='"$${DB_NAME}"'
  db_user='"$${DB_USER}"'
  db_password='"$${DB_PASSWORD}"'
  redis_auth_token='"$${REDIS_AUTH_TOKEN}"'
  auth_key='"$${AUTH_KEY}"'
  secure_auth_key='"$${SECURE_AUTH_KEY}"'
  logged_in_key='"$${LOGGED_IN_KEY}"'
  nonce_key='"$${NONCE_KEY}"'
  auth_salt='"$${AUTH_SALT}"'
  secure_auth_salt='"$${SECURE_AUTH_SALT}"'
  logged_in_salt='"$${LOGGED_IN_SALT}"'
  nonce_salt='"$${NONCE_SALT}"'
'

# Re-enable command printing.
set -x

log "Ansible playbook execution finished."

# --- 6. Final Cleanup --- #
log "Cleaning up sensitive environment variables from /etc/environment..."
# This is the final step to ensure secrets don't persist on the instance after setup.
sudo sed -i -e '/^DB_PASSWORD=/d' -e '/^REDIS_AUTH_TOKEN=/d' /etc/environment
log "Sensitive variables removed from /etc/environment."

log "Instance bootstrap complete!"
