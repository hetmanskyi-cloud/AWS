# --- IAM Configuration for ASG Instances --- #
# This file defines the IAM role, instance profile, and associated policies for EC2 instances
# managed by the Auto Scaling Group (ASG). These policies enable:
# - Access to S3 buckets (WordPress media and deployment scripts)
# - CloudWatch Agent and custom log publishing
# - Systems Manager (SSM) for secure remote management
# - KMS access for decrypting EBS and S3 objects
# - Secrets Manager access for WordPress, RDS and Redis credentials
# Temporary credentials are delivered via IMDSv2 (Instance Metadata Service v2),
# eliminating the need to hardcode or rotate keys manually.

# --- IAM Role --- #
# Allows ASG instances to assume specific permissions for accessing AWS services.
resource "aws_iam_role" "asg_role" {
  name = "${var.name_prefix}-asg-role-${var.environment}"

  # Trust policy for EC2 instances in the Auto Scaling Group
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com" # EC2 service permissions
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-asg-role-${var.environment}"
  })
}

# --- S3 Access Policy --- #
# Grants conditional access to:
# - WordPress media bucket: read/write (if enabled)
# - Scripts bucket: read-only (if enabled)
# - KMS permissions for encrypting/decrypting these buckets, if encrypted with SSE-KMS
# Policy is created only when at least one of the required buckets is enabled.
resource "aws_iam_policy" "s3_access_policy" {
  # Use can() to safely check if the keys and the 'enabled' attribute exist.
  count = (
    can(var.default_region_buckets["wordpress_media"].enabled) ||
    can(var.default_region_buckets["scripts"].enabled)
  ) ? 1 : 0

  name = "${var.name_prefix}-s3-access-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Wordpress media bucket (read/write objects)
      (can(var.default_region_buckets["wordpress_media"].enabled) && var.wordpress_media_bucket_arn != null && var.wordpress_media_bucket_arn != "") ? [{
        Sid      = "AllowWordpressMediaReadWriteDelete"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${var.wordpress_media_bucket_arn}/*"]
      }] : [],

      # Wordpress media bucket (list bucket)
      (can(var.default_region_buckets["wordpress_media"].enabled) && var.wordpress_media_bucket_arn != null && var.wordpress_media_bucket_arn != "") ? [{
        Sid      = "AllowWordpressMediaList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.wordpress_media_bucket_arn
      }] : [],

      # Scripts bucket (read-only objects)
      (can(var.default_region_buckets["scripts"].enabled) && var.scripts_bucket_arn != null && var.scripts_bucket_arn != "") ? [{
        Sid      = "AllowScriptsRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.scripts_bucket_arn}/*"
      }] : [],

      # Scripts bucket (list bucket)
      (can(var.default_region_buckets["scripts"].enabled) && var.scripts_bucket_arn != null && var.scripts_bucket_arn != "") ? [{
        Sid      = "AllowScriptsList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.scripts_bucket_arn
      }] : [],

      # KMS key permissions for bucket encryption
      (can(var.default_region_buckets["wordpress_media"].enabled) && var.kms_key_arn != null && var.kms_key_arn != "") ? [{
        Sid      = "AllowKMSForS3"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }] : []
    )
  })
}

# Attach S3 access policy to the role only if policy was created
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  count = length(aws_iam_policy.s3_access_policy) > 0 ? 1 : 0

  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.s3_access_policy[0].arn
}

# --- CloudWatch Access Policy --- #
# Enables ASG instances to publish metrics and logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.asg_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# --- CloudWatch Logs Custom Policy --- #
# Enables the CloudWatch Agent (installed manually on EC2) to:
# - Create and manage custom log groups and streams
# - Publish WordPress-related logs (e.g., Nginx, PHP-FPM, wp-debug)
# This policy is required only when using a custom CloudWatch Agent config (as in this project).

# checkov:skip=CKV_AWS_290 Justification: Wildcard resource is required for dynamically created log groups by CloudWatch Agent
# checkov:skip=CKV_AWS_355 Justification: Wildcard resource is required for dynamically created log groups by CloudWatch Agent
# tfsec:ignore:aws-iam-no-policy-wildcards CloudWatch logs require wildcard permissions to allow dynamic log group creation for WordPress components
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${var.name_prefix}-cloudwatch-logs-policy-${var.environment}"
  description = "Allows CloudWatch Agent to publish logs and access log configuration"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the custom CloudWatch Logs policy to the ASG IAM role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}


# --- Secrets Manager Access Policy --- #

# This single policy grants instance access to all required secrets:
# 1. WordPress application keys/salts
# 2. RDS database credentials
# 3. Redis AUTH token
resource "aws_iam_policy" "secrets_manager_access_policy" {
  name        = "${var.name_prefix}-secrets-access-policy-${var.environment}"
  description = "Allows instances to retrieve secrets for WordPress, RDS, and Redis."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # The Resource block lists all three secret ARNs.
        Resource = [
          var.wordpress_secrets_arn,
          var.rds_secrets_arn,
          var.redis_auth_secret_arn
        ]
      }
    ]
  })
}

# Attach the new consolidated Secrets Manager policy to the role.
resource "aws_iam_role_policy_attachment" "secrets_manager_access_policy_attachment" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.secrets_manager_access_policy.arn
}

# --- KMS Decryption Policy --- #
# This policy is created only if at least one KMS-based workflow is enabled:
# - EBS encryption (enable_ebs_encryption = true)
# - WordPress media (var.buckets["wordpress_media"].enabled = true)
# - scripts (var.buckets["scripts"].enabled = true) if using SSE-KMS
resource "aws_iam_policy" "kms_decrypt_policy" {
  count = (
    var.enable_ebs_encryption
    || can(var.default_region_buckets["wordpress_media"].enabled)
    || can(var.default_region_buckets["scripts"].enabled)
  ) ? 1 : 0

  name        = "${var.name_prefix}-kms-decrypt-policy-${var.environment}"
  description = "Allows EC2 instances to use KMS for decrypting/encrypting data (WordPress media, scripts, EBS)."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = flatten([

      # 1) WordPress media: read/write => need Encrypt/GenerateDataKey/Decrypt/DescribeKey
      can(var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_bucket_arn != null)
      ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = var.kms_key_arn
        }
      ]
      : [],

      # 2) scripts (read-only) => typically need only Decrypt/DescribeKey (if scripts bucket is SSE-KMS)
      can(var.default_region_buckets["scripts"].enabled && var.scripts_bucket_arn != null)
      ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = var.kms_key_arn
        }
      ]
      : [],

      # 3) EBS encryption => full required actions
      var.enable_ebs_encryption
      ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:CreateGrant",
            "kms:GenerateDataKeyWithoutPlainText",
            "kms:ReEncrypt*"
          ]
          Resource = var.kms_key_arn
        }
      ]
      : []
    ])
  })
}

# Attach the KMS decryption policy to the ASG IAM role to allow access to encrypted S3 objects and EBS volumes
resource "aws_iam_role_policy_attachment" "kms_access" {
  count = (
    var.enable_ebs_encryption
    || can(var.default_region_buckets["wordpress_media"].enabled)
    || can(var.default_region_buckets["scripts"].enabled)
  ) ? 1 : 0

  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy[0].arn
}

# --- IAM Instance Profile --- #
# Links the IAM role to ASG instances for accessing AWS services.
resource "aws_iam_instance_profile" "asg_instance_profile" {
  name = "${var.name_prefix}-asg-instance-profile-${var.environment}"
  role = aws_iam_role.asg_role.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-asg-instance-profile-${var.environment}"
  })
}

# --- Notes --- #
# 1. Temporary credentials:
#    - Automatically managed via the EC2 Instance Metadata Service (IMDSv2).
#    - Accessible by the instance without manual key management.
#    - Validity of 1 hour, rotated automatically by AWS.
#
# 2. S3 access:
#    - S3 access policy is created only if at least one required bucket is enabled.
#    - WordPress media bucket access is conditional, based on `default_region_buckets["wordpress_media"].enabled`.
#    - Scripts bucket access is conditional, based on `default_region_buckets["scripts"].enabled`.
#    - KMS permissions are included only when buckets are encrypted with SSE-KMS.
#
# 3. SSM policy:
#    - Provides secure management of ASG instances without requiring SSH access.
#
# 4. CloudWatch policy:
#    - Enables detailed monitoring by publishing metrics and logs to CloudWatch.
#
# 5. KMS policy:
#    - Grants permissions to decrypt S3 objects and EBS volumes encrypted with KMS.
#    - Critical for instance startup if EBS encryption is enabled to avoid boot failures.
#
# 6. Instance profile:
#    - Shared across all ASG instances, ensuring consistent access to AWS services.
#
# 7. Best practices:
#    - Review S3 bucket policies and attached permissions regularly to minimize exposure.
#    - Rotate IAM roles periodically to comply with security standards.
#
# 8. Security considerations:
#    - Use conditional policy creation to avoid empty resource lists.
#    - Ensure fine-grained access to avoid privilege escalation.
#    - Enable CloudTrail logging for IAM actions to track access.
#
# 9. Secrets Manager integration:
#    - A single, consolidated IAM policy (`secrets_manager_access_policy`) grants the instance role
#      read-only access (Get/Describe) to all three required secrets: WordPress, RDS, and Redis.
#    - This avoids storing raw passwords in Terraform variables, leverages AWS-native secrets management,
#      and simplifies policy administration.
