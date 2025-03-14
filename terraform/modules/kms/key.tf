# --- IAM Role for KMS Key Management --- #
# This role is for administrative management of the KMS key, replacing root account access for improved security and compliance.
# Strictly for administrative tasks, not for day-to-day operations or automation.
resource "aws_iam_role" "kms_role" {
  for_each = var.enable_kms_role ? { "kms_role" : "kms_role" } : {} # Enable via 'enable_kms_role' variable.

  name = "${var.name_prefix}-kms-role-${var.environment}"

  # Trust policy: Allows only root account to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root" # Root account ARN.
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for resource identification
  tags = {
    Name        = "${var.name_prefix}-kms-role"
    Environment = var.environment
  }
}

# --- IAM Policy for KMS Key Management --- #
# Policy granting minimal permissions for managing the KMS key (rotation, description).
resource "aws_iam_policy" "kms_management_policy" {
  for_each = var.enable_kms_role ? { "kms_policy" : "kms_policy" } : {} # Enable via 'enable_kms_role' variable.

  name        = "${var.name_prefix}-kms-management-policy-${var.environment}"
  description = "IAM policy for managing the KMS key"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation",
          "kms:UpdateKeyDescription"
        ],
        Resource = aws_kms_key.general_encryption_key.arn
      }
    ]
  })
}

# --- Attach Policy to IAM Role --- #
# Attaches the KMS management policy to the KMS administrative role.
resource "aws_iam_role_policy_attachment" "kms_management_attachment" {
  for_each   = var.enable_kms_role ? { "kms_attachment" : "kms_attachment" } : {} # Enable via 'enable_kms_role' variable.
  role       = aws_iam_role.kms_role["kms_role"].name
  policy_arn = aws_iam_policy.kms_management_policy["kms_policy"].arn
}

# --- Notes --- #
# 1. **Purpose**: This IAM role is for administrative management of the KMS key, replacing the need for root account access.
# 2. **Enabling the Role**: Set `enable_kms_role = true` in `terraform.tfvars` to activate this administrative role and policy.
# 3. **Manual Root Access Removal**: After KMS key creation, manually revoke root account permissions from `aws_kms_key_policy` to enforce least privilege and enhance security.
# 4. **Least Privilege**: This role grants only essential KMS key management permissions (DescribeKey, rotation control, description update), limiting potential security risks.
# 5. **Module Isolation**: Permissions for other services (e.g., S3, ASG) to *use* the KMS key are configured within their respective modules, maintaining clear separation of concerns and modularity.
# 6. **Production Security**: In production environments, thoroughly audit and further minimize permissions granted by the `kms_management_policy` as per specific security requirements.