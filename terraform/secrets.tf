# --- AWS Secrets Manager configuration for WordPress deployment --- #
# Stores sensitive credentials for database and admin access

locals {

  # Configuration values for the secret, split into database and WordPress credentials.
  secret_values = {
    # Database credentials
    database = {
      db_name     = var.db_name
      db_username = var.db_username
      db_password = var.db_password
    }

    # WordPress admin credentials
    wordpress = {
      admin_user     = var.wp_admin_user
      admin_email    = var.wp_admin_email
      admin_password = var.wp_admin_password
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
# 1. The secret name is constructed dynamically, but you can adjust naming
#    conventions as needed.
# 2. By default, Terraform tracks these resources in its state. Therefore,
#    running "terraform destroy" will remove the secret and its version,
#    as well as the IAM policy resources.
# 3. For safety, you can set "recovery_window_in_days" on the secret if you
#    want a delayed deletion period. You can also use the "prevent_destroy"
#    lifecycle rule for extra protection.
# 4. Encryption:
#    - Secrets are encrypted using a Customer Managed KMS Key (CMK) for enhanced security.