# --- Initial Configuration for KMS Key --- #
# This configuration is used for the initial creation of the KMS key with root account access.
# After creation, you must remove root access manually and switch to the IAM role for managing the KMS key.

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
# 1. **Initial Setup**:
#    - This configuration is only for the initial setup of the KMS key.
#    - Root access is required for creating the key but should be removed after initial setup.
#    - To remove root access:
#      1. Enable the IAM role management configuration in `kms/key.tf`.
#      2. Manually delete the following code from `kms/main.tf`:
#         ```hcl
#         {
#           Effect    = "Allow"
#           Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
#           Action    = "kms:*"
#           Resource  = "*"
#         }
#         ```

# 2. **Additional Principals**:
#    - Use the `additional_principals` variable to grant permissions to other roles or services.
#    - This allows for flexible and secure addition of new participants.

# 3. **Recommendations**:
#    - **Principle of Least Privilege**: After initial setup, switch to IAM roles with minimal required permissions.
#    - **CloudTrail Monitoring**: Consider enabling CloudTrail logs for tracking KMS key activities (e.g., key rotations, encryption events).
#    - **Documentation**: Maintain clear documentation for adding new participants and managing the key.