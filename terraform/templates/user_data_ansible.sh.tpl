#!/bin/bash
set -euxo pipefail # Fail fast on any error

# --- Unified logging function --- #
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Redirect all output to a log file for debugging
exec 1> >(tee -a /var/log/user-data.log) 2>&1
log "Starting Ansible-based WordPress setup..."

# --- 1. Install AWS CLI v2 (Prerequisite for fetching secrets) --- #
if ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2..."
  TMP_DIR="/tmp/awscli-setup"
  mkdir -p "$TMP_DIR"
  apt-get update -y
  apt-get install -y unzip curl
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMP_DIR/awscliv2.zip"
  unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"
  sudo "$TMP_DIR/aws/install" --update
  rm -rf "$TMP_DIR"
else
  log "AWS CLI is already installed."
fi

# --- 2. Install Ansible and Git --- #
log "Installing Ansible & Git..."
apt-get install -y ansible git

# --- 3. Clone Ansible Playbooks Repository --- #
log "Cloning Ansible playbooks repository..."
# This assumes the Ansible playbooks (including the 'terraform/ansible' structure)
# are part of the 'AWS.git' repository. The playbooks will be located at
# /opt/ansible/terraform/ansible/playbooks/install-wordpress.yml after cloning.
git clone https://github.com/hetmanskyi-cloud/AWS.git /opt/ansible
cd /opt/ansible

# --- 4. Retrieve Secrets from AWS Secrets Manager --- #
log "Retrieving all secrets from AWS Secrets Manager..."
WP_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${wordpress_secrets_name}" --query 'SecretString' --output text)
export WP_ADMIN_USER=$(echo "$WP_SECRETS" | jq -r '.ADMIN_USER')
export WP_ADMIN_EMAIL=$(echo "$WP_SECRETS" | jq -r '.ADMIN_EMAIL')
export WP_ADMIN_PASSWORD_BASE64=$(echo "$WP_SECRETS" | jq -r '.ADMIN_PASSWORD' | base64 -w0)
export AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.AUTH_KEY')
export SECURE_AUTH_KEY=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_KEY')
export LOGGED_IN_KEY=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_KEY')
export NONCE_KEY=$(echo "$WP_SECRETS" | jq -r '.NONCE_KEY')
export AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.AUTH_SALT')
export SECURE_AUTH_SALT=$(echo "$WP_SECRETS" | jq -r '.SECURE_AUTH_SALT')
export LOGGED_IN_SALT=$(echo "$WP_SECRETS" | jq -r '.LOGGED_IN_SALT')
export NONCE_SALT=$(echo "$WP_SECRETS" | jq -r '.NONCE_SALT')
RDS_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${rds_secrets_name}" --query 'SecretString' --output text)
export DB_NAME=$(echo "$RDS_SECRETS" | jq -r '.DB_NAME')
export DB_USER=$(echo "$RDS_SECRETS" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$RDS_SECRETS" | jq -r '.DB_PASSWORD')
REDIS_AUTH_SECRETS=$(aws secretsmanager get-secret-value --region "${aws_region}" --secret-id "${redis_auth_secret_name}" --query 'SecretString' --output text)
export REDIS_AUTH_TOKEN=$(echo "$REDIS_AUTH_SECRETS" | jq -r '.REDIS_AUTH_TOKEN')
log "Secrets retrieved successfully."

# --- 5. Create Extra-Vars JSON File --- #
log "Creating temporary JSON file with variables for Ansible..."
EXTRA_VARS_FILE="/tmp/extra_vars.json"

# Use a HEREDOC to create a clean JSON file.
cat <<EOF > $EXTRA_VARS_FILE
{
  "wp_config": ${wp_config},
  "cloudwatch_log_groups": ${cloudwatch_log_groups},
  "wp_version": "${wordpress_version}",
  "site_url": "${public_site_url}",
  "enable_https": ${enable_https},
  "scripts_bucket_name": "${scripts_bucket_name}",
  "efs_file_system_id": "${efs_file_system_id}",
  "efs_access_point_id": "${efs_access_point_id}",
  "enable_cloudwatch_logs": ${enable_cloudwatch_logs},
  "wp_admin_user": "$${WP_ADMIN_USER}",
  "wp_admin_password_base64": "$${WP_ADMIN_PASSWORD_BASE64}",
  "wp_admin_email": "$${WP_ADMIN_EMAIL}",
  "db_name": "$${DB_NAME}",
  "db_user": "$${DB_USER}",
  "db_password": "$${DB_PASSWORD}",
  "redis_auth_token": "$${REDIS_AUTH_TOKEN}",
  "auth_key": "$${AUTH_KEY}",
  "secure_auth_key": "$${SECURE_AUTH_KEY}",
  "logged_in_key": "$${LOGGED_IN_KEY}",
  "nonce_key": "$${NONCE_KEY}",
  "auth_salt": "$${AUTH_SALT}",
  "secure_auth_salt": "$${SECURE_AUTH_SALT}",
  "logged_in_salt": "$${LOGGED_IN_SALT}",
  "nonce_salt": "$${NONCE_SALT}"
}
EOF

log "Extra-vars file created successfully."

# --- 6. Execute Ansible Playbook --- #
log "Executing install-wordpress.yml playbook..."

# Temporarily disable command printing (-x) to prevent secrets from being logged.
set +x

# Pass the variables using the @ syntax, which tells Ansible to read from the JSON file.
ansible-playbook -i localhost, -c local terraform/ansible/playbooks/install-wordpress.yml --extra-vars "@$EXTRA_VARS_FILE"

# Re-enable command printing.
set -x

log "Ansible playbook execution finished."

# --- 7. Final Cleanup --- #
log "Cleaning up temporary extra-vars file..."
rm -f $EXTRA_VARS_FILE

log "Instance bootstrap complete!"
