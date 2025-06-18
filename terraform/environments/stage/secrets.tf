# --- AWS Secrets Manager configuration for WordPress deployment and infrastructure --- #
# Stores sensitive credentials for database, WordPress admin, and Redis access.
# This file defines the strategy for creating, storing, and rotating secrets for the entire application infrastructure.
# The rotation strategy is fully IaC-driven: changing the `secrets_version` variable
# triggers the regeneration of all keys, passwords, and salts.

# --- Random String Generation for WordPress Security Keys --- #
# Generates secure random values for all WordPress security keys and salts.
# Rotation is triggered via the `keepers` block and `secrets_version` variable.

resource "random_string" "auth_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "secure_auth_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "logged_in_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "nonce_key" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "auth_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "secure_auth_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "logged_in_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_string" "nonce_salt" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

# --- Random Password Generation for WordPress Admin and DB User --- #
resource "random_password" "wp_admin_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    version = var.secrets_version
  }
}

# --- Local Values --- #
# Defines a unified structure for all secrets, splitting credentials into database and WordPress groups for modular use.
locals {

  # Configuration values for the secret, split into RDS database and WordPress credentials.
  secret_values = {
    # Database credentials (stored in RDS secret)
    database = {
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = random_password.db_password.result
    }

    # WordPress admin credentials and security keys (stored in WordPress secret)
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

# --- Create AWS Secrets Manager secret for WordPress --- #
# Creates the main secret for WordPress, storing admin credentials and security keys.

# checkov:skip=CKV2_AWS_57: Automatic rotation is not required. Secrets are managed manually.
resource "aws_secretsmanager_secret" "wp_secrets" {
  name        = var.wordpress_secret_name
  description = "WordPress application keys, salts, and admin credentials. Rotated via IaC."

  kms_key_id = module.kms.kms_key_arn # Use Customer Managed KMS Key for encryption

  # Recommended: Add recovery window (e.g., 7 days)
  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  # Tags can be used for tracking and cost allocation.
  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-wordpress-credentials-${var.environment}"
    Rotation = "IaC-driven (via secrets_version variable)"
  })

  # Lifecycle control: allow destroy in non-production. Set to true in prod for safety.
  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

# Store the actual WordPress secret values (JSON) in the secret.
resource "aws_secretsmanager_secret_version" "wp_secrets_version" {
  secret_id = aws_secretsmanager_secret.wp_secrets.id

  # Note: The secret_string is stored in Terraform state. Avoid exposing this state publicly.
  secret_string = jsonencode(local.secret_values.wordpress) # Note: only contains WordPress data
}

# --- Store RDS Database Credentials in Secrets Manager --- #
# This resource creates a dedicated secret for RDS database credentials, separate from application secrets.
# checkov:skip=CKV2_AWS_57: Automatic rotation is not required. Secrets are managed manually.
resource "aws_secretsmanager_secret" "rds_secrets" {
  name        = var.rds_secret_name
  description = "RDS database credentials for WordPress. Rotated via IaC."
  kms_key_id  = module.kms.kms_key_arn

  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-rds-credentials-${var.environment}"
    Rotation = "IaC-driven (via secrets_version variable)"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# This resource creates a new version with the updated database password.
resource "aws_secretsmanager_secret_version" "rds_secrets_version" {
  secret_id     = aws_secretsmanager_secret.rds_secrets.id
  secret_string = jsonencode(local.secret_values.database) # Note: only contains database data
}

# --- Redis AUTH Token for ElastiCache (optional encryption in transit) --- #

# Generates and stores a strong password for Redis AUTH in a dedicated secret, only if transit_encryption_enabled = true in elasticache/main.tf.
# Randomly generated AUTH token (at least 16 characters recommended by AWS)
resource "random_password" "redis_auth_token" {
  length      = 32
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false

  keepers = {
    version = var.secrets_version
  }
}

# Store Redis AUTH token in Secrets Manager for ElastiCache
# checkov:skip=CKV2_AWS_57: Automatic rotation is not required. Secrets are managed manually.
resource "aws_secretsmanager_secret" "redis_auth" {
  name        = var.redis_auth_secret_name
  description = "Redis AUTH token for ElastiCache. Rotated via IaC."

  kms_key_id = module.kms.kms_key_arn

  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-redis-credentials-${var.environment}"
    Rotation = "IaC-driven (via secrets_version variable)"
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
#    - WordPress secret: Contains admin credentials and all WP security keys/salts.
#    - RDS secret: Contains DB_NAME, DB_USER, and DB_PASSWORD.
#    - Redis secret: Contains the REDIS_AUTH_TOKEN.
#    - Secrets are split for security, modularity, and to enforce the principle of least privilege.
#
# 2. Security:
#    - All secrets are encrypted via a Customer Managed KMS Key (CMK).
#    - All values are securely generated and rotated on-demand through the IaC workflow.
#
# 3. Access Control:
#    - Managed via IAM roles in the ASG module. Both the ARNs (for IAM policies) and names (for scripts) 
#      of the secrets must be passed as variables to the module.
#
# 4. Lifecycle:
#    - The recovery window and deletion protection settings are environment-tunable for safety in production.
#
# 5. State and CI/CD:
#    - Secret values are stored in the Terraform state file. Ensure the state backend (e.g., S3) 
#      is secure with encryption, versioning, and strict access controls.
#    - Avoid printing secret values in CI/CD logs.
#
# 6. Secrets Rotation Workflow:
#    - Rotation is controlled via the `secrets_version` variable and consists of two phases: 
#      1) updating the secret in AWS Secrets Manager, and 2) applying the new secret to the running instances.
#    - There are two scenarios for applying the rotation:
#
#    Scenario A: Rotation with an AMI Update (Standard Deployment)
#      1. Trigger: In the .tfvars file, change both `var.ami_id` and `var.secrets_version`.
#      2. Action: Run `terraform apply`.
#      3. Result: Terraform creates a new Launch Template version. The Auto Scaling Group detects this 
#         change and **automatically** triggers a rolling update (`instance_refresh`). New instances 
#         are deployed with the new AMI and fetch the new secrets on startup.
#
#    Scenario B: Rotation Only (without an AMI Update)
#      1. Phase 1 (Update Secret): In the .tfvars file, change **only** `var.secrets_version`. 
#         Run `terraform apply`. This updates the values in Secrets Manager but does not affect running instances.
#      2. Phase 2 (Apply to Instances): Manually trigger a rolling update of the instances using the AWS CLI. 
#         This forces them to restart and fetch the new secrets.
#         Command: aws autoscaling start-instance-refresh --auto-scaling-group-name <your_asg_name>
#
#    Key Takeaway: The ASG's built-in rolling update only triggers on Launch Template changes. 
#    For a secrets-only rotation, manually starting an `instance-refresh` is a required second step.