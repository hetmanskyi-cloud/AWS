# --- IAM Role for KMS Key Management --- #
# This role is used for secure administrative management of the KMS key,
# allowing the removal of root access by replacing it with a dedicated IAM role.
# Use this role only for secure manual key administration,
# not for automated or operational workflows —
# services should use dedicated IAM policies or KMS grants defined in their own modules.
resource "aws_iam_role" "kms_role" {
  for_each = var.enable_kms_role ? { "kms_role" : "kms_role" } : {} # Enable via 'enable_kms_role' variable.

  name                 = "${var.name_prefix}-kms-role-${var.environment}"
  max_session_duration = 3600 # Default limit session duration to 1 hour for better security.

  # Trust policy: Allows only the root account to assume this administrative role.
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
# This policy provides minimum necessary permissions to manage the KMS key
# (such as rotation, description updates, and basic inspection).
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
          "kms:UpdateKeyDescription",
          "kms:GetKeyPolicy"
        ],
        Resource = aws_kms_key.general_encryption_key.arn
      }
    ]
  })
}

# --- Attach Policy to IAM Role --- #
# Attaches the KMS management policy to the administrative IAM role.
resource "aws_iam_role_policy_attachment" "kms_management_attachment" {
  for_each   = var.enable_kms_role ? { "kms_attachment" : "kms_attachment" } : {} # Enable via 'enable_kms_role' variable.
  role       = aws_iam_role.kms_role["kms_role"].name
  policy_arn = aws_iam_policy.kms_management_policy["kms_policy"].arn
}

# --- Notes --- #
# 1. **Purpose**: This IAM role is designed to securely manage the KMS key,
#    replacing the use of root account permissions for ongoing maintenance.
#
# 2. **Enabling the Role**:
#    - Set `enable_kms_role = true` in terraform.tfvars to create this role and policy.
#    - Recommended after initial setup.
#
# 3. **Root Access Management**:
#    - Root access is controlled via the `kms_root_access` variable (in main.tf).
#    - Set `kms_root_access = true` during initial setup.
#    - After verifying IAM role functionality, set `kms_root_access = false` to remove root permissions from the policy.
#
# 4. **Least Privilege**:
#    - This role provides only essential management permissions (describe, rotation, and update).
#    - Avoid granting overly broad permissions (e.g., `kms:*`) unless explicitly required.
#
# 5. **Modular Separation**:
#    - Service-level KMS access (e.g., S3, ASG, RDS) is configured within their respective modules.
#    - This maintains clean separation of concerns and reduces permission sprawl.
#
# 6. **Production Security**:
#    - In production, audit the permissions in `kms_management_policy` regularly.
#    - Tighten access as needed to enforce your organization's security posture.