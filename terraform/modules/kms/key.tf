# --- IAM Role for Managing KMS Key --- #
# This role is created for administrative management of the KMS key.
# Designed to replace root-level access for better security and compliance.
# Only the root account of the AWS account can assume this role.
resource "aws_iam_role" "kms_role" {
  count = var.enable_kms_role ? 1 : 0 # Enable or disable the creation of this role dynamically

  name = "${var.name_prefix}-kms-role-${var.environment}"

  # Trust relationship limited to the root account of the AWS account
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root" # Root account ARN of the AWS account
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-kms-role"
    Environment = var.environment
  }
}

# --- IAM Policy for KMS Key Management --- #
# This policy allows minimal permissions for managing the KMS key.
resource "aws_iam_policy" "kms_management_policy" {
  count = var.enable_kms_role ? 1 : 0 # Enable or disable the creation of this policy dynamically

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

# --- Attach the Policy to the IAM Role --- #
# This resource ensures the role can perform actions allowed by the policy.
resource "aws_iam_role_policy_attachment" "kms_management_attachment" {
  count      = var.enable_kms_role ? 1 : 0 # Enable or disable the creation of this attachment dynamically
  role       = aws_iam_role.kms_role[0].name
  policy_arn = aws_iam_policy.kms_management_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - This role is created for administrative purposes, allowing manual management of the KMS key.
#    - It replaces the initial use of the root account for managing the KMS key.
#
# 2. **Enable via Variable**:
#    - Set `enable_kms_role = true` in `terraform.tfvars` to enable this configuration.
#
# 3. **Manual Root Access Removal**:
#    - Root access is initially granted in the KMS key policy for the creation of the KMS key.
#    - After creation, you must manually remove root access from the `aws_kms_key_policy` to enforce least privilege.
#
# 4. **Granular Control**:
#    - This role provides only necessary permissions for managing the KMS key (rotation, description update).
#    - Disables broad root-level access for better security and compliance.
#
# 5. **Integration with Other Resources**:
#    - This IAM role is intended solely for administrative management of the KMS key.
#    - Permissions for services such as S3 or EC2 to use the KMS key are managed within their respective Terraform modules.
#    - This ensures clear separation of responsibilities and maintains modularity.