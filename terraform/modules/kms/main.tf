# --- Initial Configuration for KMS Key --- #
# This configuration is used for the initial creation of the KMS key with root account access.
# After creation, root access can be removed by updating the policy using `aws_kms_key_policy`.

# Define a KMS key resource to encrypt CloudWatch logs, S3 buckets, and other resources
resource "aws_kms_key" "general_encryption_key" {
  description         = "General KMS key for encrypting CloudWatch logs, S3 buckets, and other resources"
  enable_key_rotation = var.enable_key_rotation # Enable automatic key rotation for added security

  tags = {
    Name        = "${var.name_prefix}-general-encryption-key-${var.environment}" # Dynamic name for the encryption key
    Environment = var.environment                                                # Environment tag for tracking
  }
}

# --- Local Variables --- #
# Define common KMS actions for reuse across policies
locals {
  kms_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncryptFrom",
    "kms:ReEncryptTo",
    "kms:GenerateDataKey*",
    "kms:DescribeKey"
  ]

  # Dynamically include services based on module configuration
  kms_services = concat(
    [
      "logs.${var.aws_region}.amazonaws.com",
      "rds.amazonaws.com",
      "elasticache.amazonaws.com",
      "delivery.logs.amazonaws.com",
      "s3.amazonaws.com",
      "ssm.amazonaws.com",
      "ssmmessages.amazonaws.com",
      "ec2messages.amazonaws.com",
      "vpc-flow-logs.amazonaws.com",
      "sqs.${var.aws_region}.amazonaws.com",
      "ec2.amazonaws.com"
    ],
    lookup(var.buckets, "logging", false) ? ["cloudtrail.amazonaws.com"] : [],
    var.enable_dynamodb ? ["dynamodb.${var.aws_region}.amazonaws.com"] : [],
    var.enable_lambda ? ["lambda.${var.aws_region}.amazonaws.com"] : [],
    var.enable_firehose ? ["firehose.${var.aws_region}.amazonaws.com"] : [],
    var.enable_waf_logging ? ["wafv2.amazonaws.com"] : []
  )

  # Extract bucket names from the buckets map for KMS policy
  s3_bucket_names = keys(var.buckets)
}

# --- Policy for KMS Key --- #
# Note: Root access is granted temporarily for key creation.
# After successful setup, ensure to manually remove root access
# from the key policy to adhere to security best practices.
resource "aws_kms_key_policy" "general_encryption_key_policy" {
  key_id = aws_kms_key.general_encryption_key.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        # 1. Root account access (temporarily for initial setup)
        {
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${var.aws_account_id}:root"
          },
          Action   = "kms:*",
          Resource = aws_kms_key.general_encryption_key.arn
        }
      ],
      [
        # 2. AWS service permissions (dynamically generated)
        for service in local.kms_services : {
          Effect    = "Allow",
          Principal = { Service = service },
          Action    = local.kms_actions,
          Resource  = aws_kms_key.general_encryption_key.arn
        }
      ],
      [
        # 3. S3-specific permissions
        {
          Effect    = "Allow",
          Principal = "*",
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
          ],
          Resource = [
            for bucket_name in local.s3_bucket_names : "arn:aws:s3:::${bucket_name}/*"
          ]
        }
      ],
      [
        # 4. Additional principals (user-defined via variables)
        for principal in var.additional_principals : {
          Effect    = "Allow",
          Principal = { AWS = principal },
          Action    = local.kms_actions,
          Resource  = aws_kms_key.general_encryption_key.arn
        }
      ]
    )
  })

  # Notes:
  # - Root access is granted temporarily and must be removed post-setup.
  # - AWS services are dynamically added based on enabled features to ensure least privilege.
  # - Additional principals allow fine-grained access control for specific accounts or roles.
}

# --- Notes --- #
# 1. Dynamic Service Permissions:
#    - The `kms_services` list dynamically includes AWS services that require access to the KMS key based on enabled features.
#    - Examples include:
#      - `enable_firehose` for Amazon Kinesis Firehose.
#      - `enable_waf_logging` for WAF logging.
#      - `enable_dynamodb` for DynamoDB.
#      - `enable_lambda` for AWS Lambda.
#    - This ensures the KMS key grants permissions only to the services actively used in the configuration, adhering to the principle of least privilege.
#
# 2. Root Access:
#    - Initial root account access is included for key management during setup.
#    - For production, consider removing root access and replacing it with tightly scoped IAM roles.
#
# 3. Key Rotation:
#    - Automatic key rotation is enabled via the `enable_key_rotation` variable for enhanced security.
#
# 4. Monitoring and Auditing:
#    - Use AWS CloudTrail to monitor key usage and track encryption/decryption operations for compliance.
#
# 5. Additional Principals:
#    - The `additional_principals` variable allows for custom roles or accounts to be granted KMS permissions as needed.
#    - Ensure any additional principals follow the principle of least privilege.