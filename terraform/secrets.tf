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

# --- Local Values --- #
# Contains configuration values for the secret, split into database and WordPress credentials.
locals {

  # Configuration values for the secret, split into database and WordPress credentials.
  secret_values = {
    # Database credentials
    database = {
      db_name     = var.db_name
      db_user     = var.db_username
      db_password = var.db_password
    }

    # WordPress admin credentials and WordPress security keys
    wordpress = {
      admin_user       = var.wp_admin_user
      admin_email      = var.wp_admin_email
      admin_password   = var.wp_admin_password
      auth_key         = random_string.auth_key.result
      secure_auth_key  = random_string.secure_auth_key.result
      logged_in_key    = random_string.logged_in_key.result
      nonce_key        = random_string.nonce_key.result
      auth_salt        = random_string.auth_salt.result
      secure_auth_salt = random_string.secure_auth_salt.result
      logged_in_salt   = random_string.logged_in_salt.result
      nonce_salt       = random_string.nonce_salt.result
    }
  }

  # Combine the database and WordPress credentials into a single JSON string.
  # This allows the aws_secretsmanager_secret_version resource to store them as one merged secret.
  wp_secrets_payload = jsonencode(
    merge(
      local.secret_values.database,
      local.secret_values.wordpress
    )
  )
}

# --- Create AWS Secrets Manager secret --- #
# This resource represents the secret container (metadata).
resource "aws_secretsmanager_secret" "wp_secrets" {
  name        = var.wordpress_secret_name
  description = "WordPress credentials for ${var.environment} environment"

  kms_key_id = module.kms.kms_key_arn # Use Customer Managed KMS Key for encryption

  # Recommended: Add recovery window (e.g., 7 days)
  recovery_window_in_days = 0

  # Tags can be used for tracking and cost allocation.
  tags = {
    Name        = "${var.name_prefix}-secrets"
    Environment = var.environment
  }

  # Optional: prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

# Store the actual secret values (JSON) in the secret.
# Merges both database and WordPress credentials into a single JSON string.
resource "aws_secretsmanager_secret_version" "wp_secrets_version" {
  secret_id = aws_secretsmanager_secret.wp_secrets.id

  # Use the write-only attribute so the secret is not stored in Terraform state
  secret_string = local.wp_secrets_payload
}

# Define an IAM policy document that grants read access to the secret.
# This policy will allow the instance to retrieve and describe the secret.
data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "AllowWordPressSecretsAccess"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [aws_secretsmanager_secret.wp_secrets.arn]
  }
}

# Attach the policy to the ASG (EC2) instance role.
# Ensures that WordPress instances can fetch the secret at runtime.
resource "aws_iam_role_policy" "secrets_access" {
  name   = "${var.wordpress_secret_name}-access"
  role   = module.asg.instance_role_id
  policy = data.aws_iam_policy_document.secrets_access.json
}

# --- Notes --- #
# 1. Secret Structure:
#    - The secret contains both database credentials and WordPress security keys
#    - All values are merged into a single JSON object for easier retrieval
# 2. Security Features:
#    - Random string generation for all WordPress security keys and salts
#    - Secrets are encrypted using a Customer Managed KMS Key (CMK) for enhanced security
#    - IAM permissions are scoped to only the specific secret ARN
# 3. Access Control:
#    - EC2 instances in the ASG are granted read-only access via IAM role policy
#    - Only GetSecretValue and DescribeSecret permissions are granted
# 4. Lifecycle Management:
#    - Recovery window is set to 0 days (immediate deletion) - adjust for production
#    - prevent_destroy is set to false - consider changing to true for production
# 5. Best Practices:
#    - Secret values are not stored in Terraform state (using write-only attribute)
#    - Tags are applied for better resource tracking and cost allocation
#    - Secret name is environment-specific to prevent cross-environment access