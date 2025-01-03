# --- Initial Configuration for KMS Key --- #
# This configuration is used for the initial creation of the KMS key with root account access.
# After creation, root access can be removed by updating the policy using `aws_kms_key_policy`.

# Define a KMS key resource to encrypt CloudWatch logs, S3 buckets, and other resources
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation # Enable automatic key rotation for added security

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key" # Dynamic name for the encryption key
    Environment = var.environment                             # Environment tag for tracking
  }
}

# --- Policy for KMS Key --- #
# Define and manage the KMS key policy to control access after creation
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat([
      # TODO: Remove root access once the KMS key is fully configured.
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }, # Initial root access
        Action    = "kms:*",
        Resource  = aws_kms_key.general_encryption_key.arn
      },
      {
        Effect    = "Allow",
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }, # Permissions for CloudWatch Logs
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.general_encryption_key.arn
      }
      ], [
      for principal in var.additional_principals : {
        Effect    = "Allow",
        Principal = { AWS = principal },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.general_encryption_key.arn
      }
    ])
  })
}

# --- Create an Alias for the KMS Key --- #
# This resource creates a user-friendly alias for the KMS key, making it easier to reference the key in other services.
resource "aws_kms_alias" "kms_alias" {
  count = var.enable_kms_alias ? 1 : 0 # Conditional creation based on the `enable_kms_alias` variable.

  # Alias name with a project-specific prefix
  name = "alias/${var.name_prefix}-kms-key"

  # The ID of the target KMS key for which the alias is created
  target_key_id = aws_kms_key.general_encryption_key.id
}

# --- Notes --- #

# 1. **Initial Setup**:
#    - This configuration provides root access during the initial setup of the KMS key.
#    - Root access remains active until it is explicitly removed from the key policy.
#    - To remove root access:
#      - Delete the corresponding root access block from the `aws_kms_key_policy`.
#      - Run `terraform plan` and `terraform apply` to update the key policy.
#      - Example for removing root access:
#        ```hcl
#        {
#          Effect    = "Allow",
#          Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" },
#          Action    = "kms:*",
#          Resource  = aws_kms_key.general_encryption_key.arn
#        }
#        ```
# 2. **Additional Principals**:
#    - Use the `additional_principals` variable to grant permissions to other roles or services.
#    - This allows for flexible and secure addition of new participants without modifying the main code.
#
# 3. **Recommendations**:
#    - **Principle of Least Privilege**: After the initial setup, replace root access with minimal permissions through IAM roles.
#    - **CloudTrail Monitoring**: Enable CloudTrail to monitor KMS key activities (e.g., encryption/decryption operations).
#    - **Documentation**: Maintain up-to-date documentation on access and participants who have permissions for the key.
#
# 4. **Alias Usage**:
#    - If the `enable_kms_alias` variable is enabled, a convenient alias for the key is created.
#    - Using aliases simplifies integration with other AWS services and key management.