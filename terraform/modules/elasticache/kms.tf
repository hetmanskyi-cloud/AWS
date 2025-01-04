# --- KMS Role and Policy for ElastiCache --- #
# This file defines an IAM role and policy to interact with KMS for ElastiCache encryption.

# --- IAM Role for KMS Access --- #
resource "aws_iam_role" "elasticache_kms_role" {
  count = var.enable_kms_elasticache_role ? 1 : 0

  name = "${var.name_prefix}-elasticache-kms-role"

  # Trust relationship for ElastiCache service
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "elasticache.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for identification and tracking
  tags = {
    Name        = "${var.name_prefix}-elasticache-kms-role"
    Environment = var.environment
  }
}

# --- IAM Policy for KMS Access --- #
resource "aws_iam_policy" "elasticache_kms_policy" {
  count = var.enable_kms_elasticache_role ? 1 : 0

  name        = "${var.name_prefix}-elasticache-kms-policy"
  description = "IAM policy for ElastiCache to access KMS for encryption and decryption"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}

# --- Attach Policy to Role --- #
resource "aws_iam_role_policy_attachment" "elasticache_kms_policy_attachment" {
  count = var.enable_kms_elasticache_role ? 1 : 0

  role       = aws_iam_role.elasticache_kms_role[0].name
  policy_arn = aws_iam_policy.elasticache_kms_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - The role and policy defined here are specific to ElastiCache and its interaction with the KMS key created in the `kms` module.
#
# 2. **Best Practices**:
#    - Use least privilege by limiting actions to only those required for encryption.
#
# 3. **Integration**:
#    - Ensure the `kms` module outputs `kms_key_arn`, which is used here.