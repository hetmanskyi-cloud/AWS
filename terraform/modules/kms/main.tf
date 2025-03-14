# --- Initial Configuration for KMS Key --- #
# Used for initial KMS key creation with temporary root account access.
# Root access should be removed after initial setup by updating the key policy via 'aws_kms_key_policy' resource.

# Define a KMS key for encrypting various AWS resources (CloudWatch logs, S3 buckets, etc.).
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation

  # Enable multi-region support for cross-region key usage.
  multi_region = true

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key-${var.environment}"
    Environment = var.environment
  }
}

# AWS provider for the replication region (if defined).
provider "aws" {
  alias  = "replication"
  region = var.replication_region
}

# Replica KMS key in the replication region for cross-region S3 replication (conditional).
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

# --- Local Variables --- #
locals {
  # Common KMS actions for various services and principals.
  kms_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ]

  # KMS actions specifically required for S3 replication.
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

  # Base AWS services requiring KMS access (AWS service principals).
  kms_services = distinct(concat(
    [
      # Regionless service principals:
      "logs.amazonaws.com",          # CloudWatch Logs
      "rds.amazonaws.com",           # RDS encryption
      "elasticache.amazonaws.com",   # ElastiCache encryption
      "s3.amazonaws.com",            # S3 encryption
      "ssm.amazonaws.com",           # Systems Manager
      "ec2.amazonaws.com",           # EBS encryption
      "wafv2.amazonaws.com",         # WAFv2
      "vpc-flow-logs.amazonaws.com", # VPC Flow Logs
    ],
    # Conditional services (enabled via variables):
    var.default_region_buckets["cloudtrail"].enabled ? ["cloudtrail.amazonaws.com"] : [], # CloudTrail Logging
    var.enable_dynamodb ? ["dynamodb.amazonaws.com"] : [],                                # DynamoDB
    var.enable_firehose ? ["firehose.amazonaws.com"] : [],                                # Firehose
    var.enable_waf_logging ? ["waf.amazonaws.com"] : []                                   # WAF (legacy)
  ))

  # List of additional principals (IAM roles, users) needing KMS access, passed via variable.
  additional_principals = distinct(var.additional_principals)

  # Extract S3 bucket names for conditional CloudTrail access in KMS policy.
  s3_bucket_names = keys(merge(var.default_region_buckets, var.replication_region_buckets))
}

# --- Policy for the Primary KMS Key --- #
# Policy for the primary KMS key granting initial root access (temporary, for setup),
# AWS service access, S3 replication permissions, and access to additional principals.
# Root access should be manually revoked from this policy after initial setup for enhanced security (see Notes).
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-1",
    Statement = flatten([
      [
        # Statement: Enable IAM User Permissions (TEMPORARY - REMOVE AFTER SETUP)
        {
          Sid    = "EnableIAMUserPermissions",
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${var.aws_account_id}:root"
          },
          Action   = "kms:*",
          Resource = "*",
        },
        # Statement: Allow AWS Services Usage
        {
          Sid    = "AllowAWSServicesUsage",
          Effect = "Allow",
          Principal = {
            Service = local.kms_services
          },
          Action   = local.kms_actions,
          Resource = "*",
        },
        # Statement: Allow S3 Replication Usage
        {
          Sid    = "AllowS3ReplicationUsage",
          Effect = "Allow",
          Principal = {
            Service = "s3.amazonaws.com"
          },
          Action   = local.s3_replication_kms_actions,
          Resource = "*",
        },
      ],
      length(local.additional_principals) > 0 ? [
        # Statement: Allow Additional Principals
        {
          Sid    = "AllowAdditionalPrincipals",
          Effect = "Allow",
          Principal = {
            AWS = local.additional_principals
          },
          Action   = local.kms_actions,
          Resource = "*",
        }
      ] : []
    ])
  })
}

# --- KMS Grant for S3 Replication on Replica Key --- #
# Granting S3 service permissions to use the replica KMS key for cross-region S3 replication.
# Replica key policies cannot be directly modified; grants are used instead.
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

# --- Notes --- #
# 1. Dynamic Service Permissions:
#    - Base services (logs, rds, etc.) are always included.
#    - Additional services are added via feature flags.
#    - Cross-account access is NOT directly configured in this module.
#    - Custom IAM roles and users via additional_principals (e.g., "arn:aws:iam::123456789012:role/example").
#
# 2. Root Access Removal Process:
#    - Initial root access is required for setup.
#    - After setup:
#      a. Set enable_kms_role = true in terraform.tfvars.
#      b. Apply to create the IAM role (in key.tf).
#      c. Remove the root access statement.
#      d. Apply changes to enforce least privilege.
#
# 3. Key Rotation:
#    - Automatic key rotation is enabled via enable_key_rotation.
#    - AWS rotates the key annually.
#    - Old versions are retained for decryption.
#    - New data is encrypted with the latest version.
#
# 4. Monitoring and Security:
#    - CloudTrail tracks key usage.
#    - CloudWatch Logs are encrypted.
#    - Consider CloudWatch Alarms for:
#         * Failed operations,
#         * Unusual usage patterns,
#         * Access denials.
#
# 5. Replica Key Grant:
#    - The replica key in the replication region cannot have its policy updated independently.
#    - A separate KMS grant (aws_kms_grant.s3_replication_grant) is created to allow S3 to perform
#      encryption and decryption operations necessary for replication.
#    - Ensure that any changes in permissions required for S3 replication are reflected in this grant.