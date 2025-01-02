# --- KMS Role and Policy for S3 Module --- #
# This file defines an IAM role and policy to interact with KMS for S3 encryption.

# --- IAM Role for S3 KMS Access --- #
# Grants the necessary permissions for S3 to interact with KMS.
resource "aws_iam_role" "s3_kms_role" {
  count = var.enable_kms_s3_role ? 1 : 0

  name = "${var.name_prefix}-s3-kms-role"

  # Trust relationship for S3 service
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for identification and tracking
  tags = {
    Name        = "${var.name_prefix}-s3-kms-role"
    Environment = var.environment
  }
}

# --- IAM Policy for S3 KMS Access --- #
# Grants S3 the required actions to use KMS for encryption and decryption.
resource "aws_iam_policy" "s3_kms_policy" {
  count = var.enable_kms_s3_role ? 1 : 0

  name        = "${var.name_prefix}-s3-kms-policy"
  description = "IAM policy for S3 to access KMS for encryption and decryption"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}

# --- Attach Policy to Role --- #
# This resource attaches the S3 KMS policy to the S3 KMS role.
resource "aws_iam_role_policy_attachment" "s3_kms_policy_attachment" {
  count = var.enable_kms_s3_role ? 1 : 0

  role       = aws_iam_role.s3_kms_role[0].name
  policy_arn = aws_iam_policy.s3_kms_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - The role and policy defined here are specific to S3 and its interaction with KMS for encryption.
#    - Only created if `enable_kms_s3_role = true` in `terraform.tfvars`.
#
# 2. **Best Practices**:
#    - Use least privilege by limiting actions to only those required for S3 encryption.
#    - Dynamically create resources based on the `enable_kms_s3_role` variable to minimize unnecessary resources.
#
# 3. **Integration**:
#    - Ensure `kms_key_arn` in `terraform.tfvars` points to a valid KMS key.
#    - Other modules can follow a similar pattern to define their specific KMS roles and policies.

# --- Optional Validation --- #
# Use `terraform plan` to validate the configuration and ensure correct KMS key reference.