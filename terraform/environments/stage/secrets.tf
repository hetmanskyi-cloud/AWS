# --- AWS Secrets Manager configuration for WordPress deployment --- #
# Stores sensitive credentials for database and admin access

# --- Random String Generation --- #
# Generates random strings for WordPress security keys.
# These are used to enhance the security of the WordPress installation.
resource "random_string" "auth_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "secure_auth_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "logged_in_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "nonce_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "auth_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "secure_auth_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "logged_in_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "nonce_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# --- Random Password Generation for WordPress Admin and DB User --- #
resource "random_password" "wp_admin_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# --- Local Values --- #
# Contains configuration values for the secret, split into database and WordPress credentials.
locals {

  # Configuration values for the secret, split into database and WordPress credentials.
  secret_values = {
    # Database credentials
    database = {
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = random_password.db_password.result
    }

    # WordPress admin credentials and WordPress security keys
    wordpress = {
      ADMIN_USER       = var.wp_admin_user
      ADMIN_EMAIL      = var.wp_admin_email
      ADMIN_PASSWORD   = random_password.wp_admin_password.result
      AUTH_KEY         = random_string.auth_key.result
      SECURE_AUTH_KEY  = random_string.secure_auth_key.result
      LOGGED_IN_KEY    = random_string.logged_in_key.result
      NONCE_KEY        = random_string.nonce_key.result
      AUTH_SALT        = random_string.auth_salt.result
      SECURE_AUTH_SALT = random_string.secure_auth_salt.result
      LOGGED_IN_SALT   = random_string.logged_in_salt.result
      NONCE_SALT       = random_string.nonce_salt.result
    }
  }
}

# --- Create AWS Secrets Manager secret --- #
# This resource represents the secret container (metadata).

# checkov:skip=CKV2_AWS_57: Automatic rotation is not required in test environments. Secrets are managed manually.
resource "aws_secretsmanager_secret" "wp_secrets" {
  name        = var.wordpress_secret_name
  description = "WordPress credentials for WordPress application (shared secret)"

  kms_key_id = module.kms.kms_key_arn # Use Customer Managed KMS Key for encryption

  # Recommended: Add recovery window (e.g., 7 days)
  recovery_window_in_days = 0

  # Tags can be used for tracking and cost allocation.
  tags = merge(local.common_tags, local.tags_secrets, {
    Name = "${var.name_prefix}-wordpress_secrets-${var.environment}"
  })

  # Lifecycle control: allow destroy in non-production. Set to true in prod for safety.
  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

# Store the actual secret values (JSON) in the secret.
resource "aws_secretsmanager_secret_version" "wp_secrets_version" {
  secret_id = aws_secretsmanager_secret.wp_secrets.id

  # Note: The secret_string is stored in Terraform state. Avoid exposing this state publicly.
  secret_string = jsonencode(
    merge(
      local.secret_values.database,
      local.secret_values.wordpress
    )
  )
}

# --- Redis AUTH Token for ElastiCache (optional encryption in transit) --- #
# This section provisions a secure password for Redis AUTH when transit_encryption_enabled = true.

# Randomly generated AUTH token (at least 16 characters recommended by AWS)
resource "random_password" "redis_auth_token" {
  length      = 32
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

# Store Redis AUTH token in Secrets Manager for ElastiCache

# checkov:skip=CKV2_AWS_57: Automatic rotation is not required in test environments. Secrets are managed manually.
resource "aws_secretsmanager_secret" "redis_auth" {
  name        = var.redis_auth_secret_name
  description = "Redis AUTH token used for connecting to ElastiCache (shared secret)"

  kms_key_id = module.kms.kms_key_arn

  recovery_window_in_days = 0

  tags = merge(local.common_tags, local.tags_secrets, {
    Name = "${var.name_prefix}-redis-auth-secret-${var.environment}"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# Store the actual auth_token
resource "aws_secretsmanager_secret_version" "redis_auth_version" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({ REDIS_AUTH_TOKEN = random_password.redis_auth_token.result })
}

# --- Notes --- #
# 1. Secret Structure:
#    - The WordPress secret contains database credentials and WordPress security keys
#    - The Redis secret contains a single key: REDIS_AUTH_TOKEN
#    - Both secrets are stored separately for security and modularity
#
# 2. Security Features:
#    - All secrets are encrypted using a Customer Managed KMS Key (CMK)
#    - WordPress salts and Redis AUTH token are generated using secure random strings
#
# 3. Access Control:
#    - Access to these secrets is managed in the ASG module (modules/asg/iam.tf)
#    - The ARN of the WordPress secret is passed to the ASG module via wordpress_secrets_arn variable
#    - The Redis AUTH secret ARN should be passed to the ASG module to grant access
#
# 4. Lifecycle Management:
#    - Recovery window is set to 0 days (immediate deletion) — adjust for production environments
#    - prevent_destroy is set to false — consider setting to true for critical secrets
#
# 5. Best Practices:
#    - Secret values **are stored** in Terraform state (no write-only workaround is used)
#    - Ensure the Terraform state is protected (e.g., S3 with encryption + access controls)
#    - Disable `terraform plan`/`apply` logs in CI/CD to avoid leaking secrets
#    - Secrets are environment-scoped to prevent accidental cross-environment use