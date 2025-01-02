# --- IAM Role for Managing KMS Key --- #
# This role is created to manage the KMS key and provide minimal required permissions.

resource "aws_iam_role" "kms_management_role" {
  count = var.enable_kms_management_role ? 1 : 0 # Enable or disable the creation of this role dynamically

  name = "${var.name_prefix}-kms-management-role"

  # Define trust relationship for IAM role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "iam.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-kms-management-role"
    Environment = var.environment
  }
}

# --- IAM Policy for KMS Key Management --- #
# This policy allows minimal permissions for managing the KMS key.

resource "aws_iam_policy" "kms_management_policy" {
  count = var.enable_kms_management_role ? 1 : 0 # Enable or disable the creation of this policy dynamically

  name        = "${var.name_prefix}-kms-management-policy"
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

# --- Attach the Policy to the IAM Role --- #
# This resource ensures the role can perform actions allowed by the policy.

resource "aws_iam_role_policy_attachment" "kms_management_attachment" {
  count      = var.enable_kms_management_role ? 1 : 0 # Enable or disable the creation of this attachment dynamically
  role       = aws_iam_role.kms_management_role[0].name
  policy_arn = aws_iam_policy.kms_management_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - This role replaces the initial use of the root account for managing the KMS key.
#    - Provides granular permissions for securely managing the KMS key after its creation.
#
# 2. **Enable via Variable**:
#    - Set `enable_kms_management = true` in `terraform.tfvars` to enable this configuration.
#
# 3. **Root Access Removal**:
#    - Before enabling this module, manually remove the root access policy from the `kms/main.tf` file:
#      ```hcl
#      {
#        Effect    = "Allow"
#        Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" } # Access for account owner
#        Action    = "kms:*"
#        Resource  = "*"
#      }
#      ```
#
# 4. **Granular Control**:
#    - Provides only necessary permissions for managing the KMS key (rotation, description update).
#    - Disables broad root-level access for better security and compliance.