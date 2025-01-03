# --- IAM Role for Managing KMS Key --- #
# This role is created for administrative management of the KMS key.
# Designed to replace root-level access for better security and compliance.
# Trust relationship allows only the root account of the AWS account to assume this role.
resource "aws_iam_role" "kms_role" {
  count = var.enable_kms_role ? 1 : 0 # Enable or disable the creation of this role dynamically

  name = "${var.name_prefix}-kms-role"

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
# 3. **Dynamic Root Access Update**:
#    - Root access is initially granted for the creation of the KMS key in `kms/main.tf`.
#    - After creation, Terraform dynamically updates the policy using the `aws_kms_key_policy` resource to remove root access and enforce least privilege.
#
# 4. **Granular Control**:
#    - This role provides only necessary permissions for managing the KMS key (rotation, description update).
#    - Disables broad root-level access for better security and compliance.
#
# 5. **Integration with Other Resources**:
#    - This role is intended only for administrative purposes (manual management of the KMS key).
#    - Access for services like S3 or EC2 should be defined in their respective modules.
#      - For example, the S3 module will include the necessary policies to interact with the KMS key.
#      - This approach ensures clear separation of responsibilities and modularity.