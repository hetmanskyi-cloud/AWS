# --- Initial Configuration for KMS Key ---
# This configuration is used for the initial creation of the KMS key with root account access.
# After creation, root access can be removed by updating the policy using `aws_kms_key_policy`.

# Define a KMS key resource to encrypt CloudWatch logs, S3 buckets, and other resources
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation

  # Multi-region key to allow cross-region usage
  multi_region = true

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key-${var.environment}"
    Environment = var.environment
  }
}

# AWS provider for the replication region
provider "aws" {
  alias  = "replication"
  region = var.replication_region
}

# Replica of a multi-region KMS key in a replication region
resource "aws_kms_replica_key" "replica_key" {
  count = var.replication_region != "" ? 1 : 0

  provider        = aws.replication
  description     = "Replica of general encryption key for S3 replication in ${var.replication_region}"
  primary_key_arn = aws_kms_key.general_encryption_key.arn

  tags = {
    Name        = "${var.name_prefix}-replica-key-${var.environment}"
    Environment = var.environment
  }
}

# --- Local Variables ---
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

  # Additional KMS actions specifically for S3 replication
  s3_replication_kms_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey",
    "kms:GenerateDataKeyWithoutPlaintext",
    "kms:DescribeKey",
    "kms:CreateGrant"
  ]

  # Base AWS services that require KMS access (regionless principals)
  kms_services = distinct(concat(
    [
      # Regionless service principals:
      "logs.amazonaws.com",        # CloudWatch Logs
      "rds.amazonaws.com",         # RDS encryption
      "elasticache.amazonaws.com", # ElastiCache encryption
      "s3.amazonaws.com",          # S3 encryption
      "ssm.amazonaws.com",         # Systems Manager
      "ec2.amazonaws.com",         # EBS encryption
      "wafv2.amazonaws.com",       # WAFv2
      "vpc-flow-logs.amazonaws.com"
    ],
    # Conditional services:
    var.default_region_buckets["logging"].enabled ? ["cloudtrail.amazonaws.com"] : [],
    var.enable_dynamodb ? ["dynamodb.amazonaws.com"] : [],
    var.enable_lambda ? ["lambda.amazonaws.com"] : [],
    var.enable_firehose ? ["firehose.amazonaws.com"] : [],
    var.enable_waf_logging ? ["waf.amazonaws.com"] : []
  ))

  # Additional principals that need KMS access (IAM roles and users)
  additional_principals = distinct(var.additional_principals)

  # Extract bucket names from the buckets map
  # Used for conditional CloudTrail service access
  s3_bucket_names = keys(merge(var.default_region_buckets, var.replication_region_buckets))
}

# --- Policy for the Primary KMS Key ---
# Note: Root access is granted temporarily for key creation.
# After successful setup:
# 1. Create an IAM role using key.tf (set enable_kms_role = true)
# 2. Remove the "Enable IAM User Permissions" statement below
# 3. Apply changes to enforce least privilege
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-1",
    Statement = flatten([
      [
        {
          Sid    = "EnableIAMUserPermissions",
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${var.aws_account_id}:root"
          },
          Action   = "kms:*",
          Resource = "*"
        },
        {
          Sid    = "AllowAWSServicesUsage",
          Effect = "Allow",
          Principal = {
            Service = local.kms_services
          },
          Action   = local.kms_actions,
          Resource = "*"
        },
        {
          Sid    = "AllowS3ReplicationUsage",
          Effect = "Allow",
          Principal = {
            Service = "s3.amazonaws.com"
          },
          Action   = local.s3_replication_kms_actions,
          Resource = "*"
        }
      ],
      length(local.additional_principals) > 0 ? [
        {
          Sid    = "AllowAdditionalPrincipals",
          Effect = "Allow",
          Principal = {
            AWS = local.additional_principals
          },
          Action   = local.kms_actions,
          Resource = "*"
        }
      ] : []
    ])
  })
}

# --- Grant for S3 Replication on the Replica KMS Key --- #
# Since the replica key's policy cannot be updated directly,
# we create a KMS grant to allow S3 to use the replica key for encryption and decryption.
resource "aws_kms_grant" "s3_replication_grant" {
  count             = var.replication_region != "" ? 1 : 0
  key_id            = aws_kms_replica_key.replica_key[0].id
  grantee_principal = "s3.amazonaws.com"

  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant"
  ]

  name = "S3ReplicationGrant"
}

# --- Notes ---
# 1. Dynamic Service Permissions:
#    - Base services (logs, rds, etc.) are always included.
#    - Additional services are added via feature flags.
#    - Cross-account access via additional_account_ids (e.g., "123456789012").
#    - Custom IAM roles via additional_principals (e.g., "arn:aws:iam::123456789012:role/example").
#
# 2. Root Access Removal Process:
#    - Initial root access is required for setup.
#    - After setup:
#      a. Set enable_kms_role = true in terraform.tfvars.
#      b. Apply to create the IAM role (in key.tf).
#      c. Remove the root access statement.
#      d. Apply changes to enforce least privilege.
#
# 3. Key Rotation:
#    - Automatic key rotation is enabled via enable_key_rotation.
#    - AWS rotates the key annually.
#    - Old versions are retained for decryption.
#    - New data is encrypted with the latest version.
#
# 4. Monitoring and Security:
#    - CloudTrail tracks key usage.
#    - CloudWatch Logs are encrypted.
#    - Consider CloudWatch Alarms for:
#         * Failed operations,
#         * Unusual usage patterns,
#         * Access denials.
#
# 5. Replica Key Grant:
#    - The replica key in the replication region cannot have its policy updated independently.
#    - A separate KMS grant (aws_kms_grant.s3_replication_grant) is created to allow S3 to perform
#      encryption and decryption operations necessary for replication.
#    - Ensure that any changes in permissions required for S3 replication are reflected in this grant.