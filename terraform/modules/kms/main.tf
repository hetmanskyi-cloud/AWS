# --- Initial Configuration for KMS Key --- #
# Root account access is controlled via the `kms_root_access` variable.
# Set to true during initial setup, and to false afterward to automatically remove root permissions from the key policy.

# Define a KMS key for encrypting various AWS resources (CloudWatch logs, S3 buckets, etc.).
# This is a Customer Managed Key (CMK), fully managed and controlled within this project.
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation

  # Enable multi-region support for cross-region key usage.
  # This must be set to true when using KMS replica keys for S3 replication or other cross-region scenarios.
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
  count = length({ for k, v in var.replication_region_buckets : k => v if v.enabled }) > 0 ? 1 : 0

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
  kms_actions = distinct([
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey*",
    "kms:GenerateDataKeyWithoutPlaintext",
    "kms:DescribeKey"
  ])

  # KMS actions specifically required for S3 replication.
  s3_replication_kms_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey",
    "kms:GenerateDataKeyWithoutPlaintext",
    "kms:DescribeKey"
  ]

  # KMS Grant Operations (used in aws_kms_grant)
  s3_replication_grant_operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant"
  ]

  # Base AWS services requiring KMS access (AWS service principals).
  kms_services = distinct(concat(
    [
      # Regionless service principals:
      "logs.amazonaws.com",           # CloudWatch Logs
      "rds.amazonaws.com",            # RDS encryption
      "elasticache.amazonaws.com",    # ElastiCache encryption
      "s3.amazonaws.com",             # S3 encryption
      "ssm.amazonaws.com",            # Systems Manager
      "ec2.amazonaws.com",            # EBS encryption
      "wafv2.amazonaws.com",          # WAFv2
      "vpc-flow-logs.amazonaws.com",  # VPC Flow Logs
      "secretsmanager.amazonaws.com", # Secrets Manager for Secrets encryption
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
# Policy for the primary KMS key granting optional root access (temporary, for setup),
# AWS service access, S3 replication permissions, and access to additional principals.
# Root access is controlled by the 'remove_root_access' variable for automation and security.
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-1",
    Statement = flatten([
      [
        # Statement: Root access for the KMS key (enabled via kms_root_access = true)
        var.kms_root_access ? [
          {
            Sid    = "EnableIAMUserPermissions",
            Effect = "Allow",
            Principal = {
              AWS = "arn:aws:iam::${var.aws_account_id}:root"
            },
            Action   = "kms:*",
            Resource = "*"
          }
        ] : [],

        # Statement: Allow AWS service usage with restricted resource (only this KMS key).
        {
          Sid    = "AllowAWSServicesUsage",
          Effect = "Allow",
          Principal = {
            Service = local.kms_services
          },
          Action   = local.kms_actions,
          Resource = aws_kms_key.general_encryption_key.arn
        },

        # Statement: Allow S3 Replication Usage
        {
          Sid    = "AllowS3ReplicationUsage",
          Effect = "Allow",
          Principal = {
            Service = "s3.amazonaws.com"
          },
          Action   = local.s3_replication_kms_actions,
          Resource = aws_kms_key.general_encryption_key.arn
        }
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
          Resource = aws_kms_key.general_encryption_key.arn
        }
      ] : []
    ])
  })

  # Notes:
  # 1. Root access to the KMS key is controlled by the 'kms_root_access' variable.
  #    Set to `true` during initial setup to allow full administrative access via the root account.
  #    Before setting it to `false`, make sure to set `enable_admin_kms_role = true` to provision an IAM role for secure key management.
  #    This ensures that administrative access remains available after root permissions are removed.
  #
  # 2. If EC2 instances are later moved to private subnets without internet access,
  #    enable the KMS VPC Endpoint by setting 'enable_interface_endpoints = true'.
  #    AWS will automatically route encryption traffic through the private VPC connection when available.
}

# --- KMS Grant for S3 Replication on Replica Key --- #
# Granting S3 service permissions to use the replica KMS key for cross-region S3 replication.
# Replica key policies cannot be directly modified; grants are used instead.
resource "aws_kms_grant" "s3_replication_grant" {
  count = length({ for k, v in var.replication_region_buckets : k => v if v.enabled }) > 0 ? 1 : 0

  key_id            = aws_kms_replica_key.replica_key[0].id
  grantee_principal = "s3.amazonaws.com"

  operations = local.s3_replication_grant_operations

  name = "S3ReplicationGrant"

  depends_on = [aws_kms_replica_key.replica_key] # Ensure replica key is created first
}

# --- Notes --- #
# 1. Dynamic Service Permissions:
#    - Base services (logs, rds, etc.) are always included.
#    - secretsmanager.amazonaws.com is added by default for secrets encryption.
#    - Additional services are added via feature flags.
#    - Cross-account access is NOT directly configured in this module.
#    - Custom IAM roles and users via additional_principals (e.g., "arn:aws:iam::123456789012:role/example").
#
# 2. Root Access Management (`aws_kms_key_policy.general_encryption_key_policy`):
#    - Root access is controlled via the 'kms_root_access' variable.
#    - When kms_root_access = true:
#        → Full permissions are granted to the account root (useful during initial setup).
#    - When kms_root_access = false:
#        → Root permissions are removed to enforce least privilege.
#    - Recommended flow:
#        a. Set kms_root_access = true and apply to create the key.
#        b. Set enable_admin_kms_role = true and apply to create the IAM role.
#        c. Set kms_root_access = false and re-apply to remove root access.
#
# 3. Key Rotation:
#    - Automatic key rotation is enabled via enable_key_rotation.
#    - AWS rotates the key annually.
#    - Old versions are retained for decryption.
#    - New data is encrypted with the latest version.
#
# 4. Monitoring and Security:
#    - AWS CloudTrail automatically logs all KMS API calls.
#    - This KMS key is intended to encrypt CloudWatch Logs (via other modules).
#    - For production use, consider adding CloudWatch Alarms for:
#         * Failed encryption operations,
#         * Unusual usage patterns,
#         * Access denials (e.g., key policy issues).
#
# 5. Replica Key Grant:
#    - The replica key in the replication region cannot have its policy updated independently.
#    - A separate KMS grant (aws_kms_grant.s3_replication_grant) is created to allow S3 to perform
#      encryption and decryption operations necessary for replication.
#    - Ensure that any changes in permissions required for S3 replication are reflected in this grant.
#
# 6. Replica KMS key and KMS Grant for S3 Replication on Replica Key are dynamically created only when replication buckets are enabled.
#    Ensure replication_region in terraform.tfvars matches the replication_region_buckets configuration.