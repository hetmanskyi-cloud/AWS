# --- KMS Role and Policy for ALB Module --- #
# This file defines an IAM role and policy to interact with KMS for ALB encryption.

# --- IAM Role for ALB KMS Access --- #
resource "aws_iam_role" "alb_kms_role" {
  count = var.enable_kms_alb_role ? 1 : 0

  name = "${var.name_prefix}-alb-kms-role"

  # Trust relationship for ALB service
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for identification and tracking
  tags = {
    Name        = "${var.name_prefix}-alb-kms-role"
    Environment = var.environment
  }
}

# --- IAM Policy for ALB KMS Access --- #
resource "aws_iam_policy" "alb_kms_policy" {
  count = var.enable_kms_alb_role ? 1 : 0

  name        = "${var.name_prefix}-alb-kms-policy"
  description = "IAM policy for ALB to access KMS for encryption and decryption"

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
resource "aws_iam_role_policy_attachment" "alb_kms_policy_attachment" {
  count = var.enable_kms_alb_role ? 1 : 0

  role       = aws_iam_role.alb_kms_role[0].name
  policy_arn = aws_iam_policy.alb_kms_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - The role and policy defined here are specific to ALB and its interaction with the KMS key created in the `kms` module.
#    - Only created if `enable_kms_alb_role = true`.
#
# 2. **Best Practices**:
#    - Use least privilege by limiting actions to only those required for ALB encryption.
#    - Dynamically create resources based on the `enable_kms_alb_role` variable to minimize unnecessary resources.
#
# 3. **Integration**:
#    - Ensure the `kms` module outputs `kms_key_arn`, which is used here.
#    - This approach keeps the configuration centralized and reduces manual input requirements.