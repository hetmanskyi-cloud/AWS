# --- Initial Configuration for KMS Key --- #
# This configuration is used for the initial creation of the KMS key with root account access.
# After creation, root access can be removed by updating the policy using `aws_kms_key_policy`.

# Define a KMS key resource to encrypt CloudWatch logs, S3 buckets, and other resources
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key-${var.environment}"
    Environment = var.environment
  }
}

# --- Local Variables --- #
locals {
  # Common KMS actions for additional principals
  kms_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ]

  # Base AWS services that require KMS access
  kms_services = distinct(concat(
    [
      "logs.${var.aws_region}.amazonaws.com", # CloudWatch Logs
      "rds.amazonaws.com",                    # RDS encryption
      "elasticache.amazonaws.com",            # ElastiCache encryption
      "s3.amazonaws.com",                     # S3 bucket encryption
      "ssm.${var.aws_region}.amazonaws.com",  # Systems Manager
      "ec2.${var.aws_region}.amazonaws.com",  # EBS encryption
      "wafv2.amazonaws.com",                  # WAF configuration
      "vpc-flow-logs.amazonaws.com"           # VPC Flow Logs
    ],
    # Optional services enabled by feature flags
    lookup(var.buckets, "logging", false) ? ["cloudtrail.amazonaws.com"] : [],
    var.enable_dynamodb ? ["dynamodb.${var.aws_region}.amazonaws.com"] : [],
    var.enable_lambda ? ["lambda.${var.aws_region}.amazonaws.com"] : [],
    var.enable_firehose ? ["firehose.${var.aws_region}.amazonaws.com"] : [],
    var.enable_waf_logging ? ["waf.${var.aws_region}.amazonaws.com"] : []
  ))

  # Additional principals that need KMS access (IAM roles and users)
  additional_principals = distinct(var.additional_principals)

  # Extract bucket names from the buckets map
  # Used for conditional CloudTrail service access
  s3_bucket_names = keys(var.buckets)
}

# --- Policy for KMS Key --- #
# Note: Root access is granted temporarily for key creation.
# After successful setup:
# 1. Create IAM role using key.tf (set enable_kms_role = true)
# 2. Remove the "Enable IAM User Permissions" statement below
# 3. Apply the changes to enforce least privilege
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy-1"
    Statement = concat([
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
      ],
      # Add statement for additional principals if any exist
      length(local.additional_principals) > 0 ? [{
        Sid    = "Allow Additional Principals"
        Effect = "Allow"
        Principal = {
          AWS = local.additional_principals
        }
        Action   = local.kms_actions
        Resource = "*"
    }] : [])
  })
}

# --- Notes --- #
# 1. Dynamic Service Permissions:
#    - Base services (logs, rds, etc.) are always included
#    - Additional services added via feature flags
#    - Cross-account access via additional_account_ids (e.g., "123456789012")
#    - Custom IAM roles via additional_principals (e.g., "arn:aws:iam::123456789012:role/example")
#
# 2. Root Access Removal Process:
#    - Initial root access required for setup
#    - After setup:
#      a. Set enable_kms_role = true in terraform.tfvars
#      b. Apply to create the IAM role (key.tf)
#      c. Remove root access statement
#      d. Apply changes for least privilege
#
# 3. Key Rotation:
#    - Automatic key rotation via enable_key_rotation
#    - AWS rotates key annually
#    - Old versions retained for decryption
#    - New data encrypted with latest version
#
# 4. Monitoring and Security:
#    - CloudTrail tracks key usage
#    - CloudWatch Logs encrypted
#    - Consider CloudWatch Alarms for:
#      * Failed operations
#      * Unusual usage patterns
#      * Access denials