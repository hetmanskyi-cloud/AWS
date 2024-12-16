# --- General Encryption Key Configuration for CloudWatch Logs and S3 Buckets --- #

# Define a KMS key resource to encrypt CloudWatch logs, S3 buckets, and other resources
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = true # Enable automatic key rotation for added security

  # KMS key policy with base permissions and additional principals if specified
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat(local.base_statements, local.additional_statements)
  })

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key" # Dynamic name for the encryption key
    Environment = var.environment                             # Environment tag for tracking
  }
}

# --- Policy Statements for KMS Key --- #

# Define local variables for base and additional permissions
locals {
  # Base permissions required for using the KMS key
  base_statements = [
    {
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" } # Access for account owner
      Action    = "kms:*"
      Resource  = "*"
    },
    {
      Effect    = "Allow"
      Principal = { Service = "logs.${var.aws_region}.amazonaws.com" } # Permissions for CloudWatch Logs
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ]

  # Additional permissions for the KMS key if specified in additional_principals
  additional_statements = [
    for principal in var.additional_principals : {
      Effect    = "Allow"
      Principal = { AWS = principal }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ]
}

# --- Notes --- #

# 1. This KMS key is designed for general encryption purposes, such as CloudWatch Logs and S3 buckets.
# 2. Automatic key rotation is enabled to enhance security and compliance.
# 3. Additional permissions can be granted dynamically using the additional_principals variable.