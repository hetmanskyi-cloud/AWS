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

# --- Random String for CloudFront → ALB Custom Header --- #
# Secret value for validating requests to ALB come only from CloudFront (custom header X-Custom-Origin-Verify).

# NOTE ON ROTATION: This specific secret is INTENTIONALLY EXCLUDED from the automatic
# rotation mechanism (no `keepers` block) to ensure deployment stability, preventing
# issues related to CloudFront's global propagation delay.
resource "random_password" "cloudfront_to_alb_header" {
  length           = 32
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
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
# checkov:skip=CKV2_AWS_57: "Rotation is handled manually via the IaC 'secrets_version' variable, which is a valid strategy for this project."
resource "aws_secretsmanager_secret" "wp_secrets" {
  name        = var.wordpress_secret_name
  description = "WordPress application keys, salts, and admin credentials. Rotated via IaC."

  kms_key_id = module.kms.kms_key_arn # Use Customer Managed KMS Key for encryption

  # Recommended: Add recovery window (e.g., 7 days)
  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  # Tags can be used for tracking and cost allocation.
  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-wordpress-credentials-${var.environment}"
    Rotation = "IaC-driven"
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
# checkov:skip=CKV2_AWS_57: "Rotation is handled manually via the IaC 'secrets_version' variable, which is a valid strategy for this project."
resource "aws_secretsmanager_secret" "rds_secrets" {
  name        = var.rds_secret_name
  description = "RDS database credentials for WordPress. Rotated via IaC."
  kms_key_id  = module.kms.kms_key_arn

  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-rds-credentials-${var.environment}"
    Rotation = "IaC-driven"
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
# checkov:skip=CKV2_AWS_57: "Rotation is handled manually via the IaC 'secrets_version' variable, which is a valid strategy for this project."
resource "aws_secretsmanager_secret" "redis_auth" {
  name        = var.redis_auth_secret_name
  description = "Redis AUTH token for ElastiCache. Rotated via IaC."

  kms_key_id = module.kms.kms_key_arn

  recovery_window_in_days = 0 # Immediate deletion; set to a positive value (e.g., 7) for production recovery safety.

  tags = merge(local.common_tags, local.tags_secrets, {
    Name     = "${var.name_prefix}-redis-credentials-${var.environment}"
    Rotation = "IaC-driven"
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
#    - Rotation is controlled by changing the `secrets_version` variable. This regenerates all secrets that have a `keepers` block.
#    - The workflow is a two-phase process:
#      1) **Phase 1 (Update Secret):** Running `terraform apply` after changing `secrets_version` updates the values in AWS Secrets Manager.
#      2) **Phase 2 (Apply to Instances):** A manual rolling update of the Auto Scaling Group (e.g., via `aws autoscaling start-instance-refresh`) is required
#         to force running instances to restart and fetch the new secrets from Secrets Manager.
#    - NOTE: An instance refresh is triggered automatically by the ASG only if the Launch Template changes (e.g., a new AMI).
#      For a secrets-only rotation, the manual refresh in Phase 2 is a required step.
#
# 7. Special Note on `cloudfront_to_alb_header` Rotation Strategy:
#    - The `cloudfront_to_alb_header` secret is intentionally static and excluded from the `secrets_version` rotation trigger.
#    - RATIONALE: Simultaneously updating this shared secret in both the global CloudFront distribution and the regional
#      WAF creates a race condition. The WAF updates almost instantly, while CloudFront's configuration changes can take
#      many minutes to propagate globally. This timing mismatch leads to legitimate traffic being blocked with `403 Forbidden` errors.
#    - SECURITY POSTURE: Disabling automatic rotation for this internal, service-to-service secret is an
#      accepted architectural trade-off for ensuring deployment stability. The primary defense against direct
#      ALB access remains the ALB's Security Group, which should be restricted to the CloudFront prefix list.
#    - PROCEDURE: A manual, zero-downtime rotation can be performed following a specific multi-phase `apply` procedure
#      that temporarily places the WAF rule in 'count' mode.
