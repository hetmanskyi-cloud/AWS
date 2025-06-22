# Terraform version and provider requirements
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-general-encryption-key-${var.environment}"
  })
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-replica-key-${var.environment}"
  })
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
    "kms:DescribeKey",
    "kms:CreateGrant"
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
      "cloudfront.amazonaws.com",     # CloudFront
    ],
    # Conditional services (enabled via variables):
    contains(keys(var.default_region_buckets), "cloudtrail") && try(var.default_region_buckets["cloudtrail"].enabled, false) ? ["cloudtrail.amazonaws.com"] : [], # CloudTrail Logging
    var.enable_dynamodb ? ["dynamodb.amazonaws.com"] : [],                                                                                                        # DynamoDB
    (var.enable_alb_firehose || var.enable_cloudfront_firehose) ? ["firehose.amazonaws.com"] : [],                                                                # ALB & CloudFront Firehose
    (var.enable_alb_waf_logging || var.enable_cloudfront_waf) ? ["waf.amazonaws.com"] : [],                                                                       # ALB & Cloudfront WAF
    var.enable_cloudfront_standard_logging_v2 ? ["delivery.logs.amazonaws.com"] : [],                                                                             # CloudFront Realtime S3 Logging
  ))
}

# --- Policy for the Primary KMS Key --- #
# Policy for the primary KMS key granting optional root access (temporary, for setup),
# AWS service access, S3 replication permissions, and specific permissions for AutoScaling service role.
# Root access is controlled by the 'kms_root_access' variable (set to false after setup).
# If root access is disabled, you must ensure an IAM role (with PutKeyPolicy) remains authorized.
# Otherwise, you may permanently lose the ability to modify the key policy (AWS protection applies).
# EBS encryption is supported through dedicated statements for EC2 and AutoScaling service roles.
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

        # Statement: Allow IAM policies to control access to the key
        # This statement is required by AWS KMS to prevent locking out of the key
        # It allows IAM policies to grant permissions to the key, even when root access is disabled
        # CRITICAL: This statement is essential for safely disabling root access (kms_root_access = false)
        # without losing the ability to manage the key policy in the future
        {
          Sid    = "EnableIAMPermissions",
          Effect = "Allow",
          Principal = {
            AWS = "*"
          },
          Action   = "kms:*",
          Resource = "*",
          Condition = {
            StringEquals = {
              "kms:CallerAccount" = var.aws_account_id
            }
          }
        },

        # Statement: Allow KMS Admin Role key management permissions
        # This statement is critical for key management when root access is disabled
        var.enable_kms_admin_role ? [
          {
            Sid    = "AllowKMSAdminRoleKeyManagement",
            Effect = "Allow",
            Principal = {
              AWS = "arn:aws:iam::${var.aws_account_id}:role/${var.name_prefix}-kms-admin-role-${var.environment}"
            },
            Action   = "kms:*",
            Resource = "*"
          }
        ] : [],

        # Statement: Allow AWS services to use the KMS key
        {
          Sid    = "AllowAWSServicesUsage",
          Effect = "Allow",
          Principal = {
            Service = local.kms_services
          },
          Action   = local.kms_actions,
          Resource = aws_kms_key.general_encryption_key.arn
        },

        # Statement: Allow EC2 to CreateGrant for root EBS volume encryption (critical for instance launch)
        {
          Sid    = "AllowEC2LaunchGrant",
          Effect = "Allow",
          Principal = {
            Service = "ec2.amazonaws.com"
          },
          Action = [
            "kms:CreateGrant"
          ],
          Resource = aws_kms_key.general_encryption_key.arn,
          Condition = {
            Bool = {
              "kms:GrantIsForAWSResource" = "true"
            }
          }
        },

        # Statement: Allow AutoScaling service role to perform basic operations on the KMS key
        # This follows AWS best practices for EBS encryption with AutoScaling
        {
          Sid    = "AllowAutoScalingServiceRoleUsage",
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          },
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ],
          Resource = "*"
        },

        # Statement: Allow AutoScaling service role to create grants for AWS resources
        # This is required for the AutoScaling service to delegate permissions to EC2 for EBS encryption
        {
          Sid    = "AllowAutoScalingServiceRoleCreateGrant",
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          },
          Action = [
            "kms:CreateGrant"
          ],
          Resource = "*",
          Condition = {
            Bool = {
              "kms:GrantIsForAWSResource" = "true"
            }
          }
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
      ]
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

  key_id            = length(aws_kms_replica_key.replica_key) > 0 ? aws_kms_replica_key.replica_key[0].id : null
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
# 2.1. Key Policy Lockout Protection:
#    - The statement "EnableIAMPermissions" is an essential part of the key policy.
#    - It ensures that IAM policies can control access to the KMS key when root access is disabled.
#    - This allows authorized IAM roles or users to manage the key using their own permissions.
#    - Without this statement, disabling root access may result in permanent lockout from the key.
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
#    - Use CloudTrail event lookup or AWS IAM Access Analyzer to audit unexpected usage.
#    - You can also enable KMS-specific alarms (e.g., AccessDenied, ThrottledRequests).
#
# 5. Replica Key Grant:
#    - The replica key in the replication region cannot have its policy updated independently.
#    - A separate KMS grant (aws_kms_grant.s3_replication_grant) is created to allow S3 to perform
#      encryption and decryption operations necessary for replication.
#    - Ensure that any changes in permissions required for S3 replication are reflected in this grant.
#
# 6. Replica KMS key and KMS Grant for S3 Replication on Replica Key are dynamically created only when replication buckets are enabled.
#    Ensure replication_region in terraform.tfvars matches the replication_region_buckets configuration.
