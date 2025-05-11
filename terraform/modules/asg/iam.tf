# --- IAM Configuration for ASG Instances --- #
# This file defines the IAM role, instance profile, and associated policies for EC2 instances
# managed by the Auto Scaling Group (ASG). These policies enable:
# - Access to S3 buckets (WordPress media and deployment scripts)
# - CloudWatch Agent and custom log publishing
# - Systems Manager (SSM) for secure remote management
# - KMS access for decrypting EBS and S3 objects
# - Secrets Manager access for WordPress and Redis credentials
# Temporary credentials are delivered via IMDSv2 (Instance Metadata Service v2),
# eliminating the need to hardcode or rotate keys manually.

# --- IAM Role --- #
# Allows ASG instances to assume specific permissions for accessing AWS services.
resource "aws_iam_role" "asg_role" {
  name = "${var.name_prefix}-asg-role"

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
    Name = "${var.name_prefix}-asg-role"
  })
}

# --- S3 Access Policy --- #
# Grants conditional access to:
# - WordPress media bucket: read/write (if enabled)
# - Scripts bucket: read-only (if enabled)
# - KMS permissions for encrypting/decrypting these buckets, if encrypted with SSE-KMS
# Policy is created only when at least one of the required buckets is enabled.
resource "aws_iam_policy" "s3_access_policy" {
  count = (
    var.default_region_buckets["wordpress_media"].enabled ||
    var.default_region_buckets["scripts"].enabled
  ) ? 1 : 0

  name = "${var.name_prefix}-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Wordpress media bucket (read/write)
      var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_bucket_arn != null && var.wordpress_media_bucket_arn != "" ? [{
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.wordpress_media_bucket_arn}/*"]
      }] : [],

      var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_bucket_arn != null && var.wordpress_media_bucket_arn != "" ? [{
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.wordpress_media_bucket_arn
      }] : [],

      # Scripts bucket (read-only)
      var.default_region_buckets["scripts"].enabled && var.scripts_bucket_arn != null && var.scripts_bucket_arn != "" ? [{
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "${var.scripts_bucket_arn}/*"
      }] : [],

      var.default_region_buckets["scripts"].enabled && var.scripts_bucket_arn != null && var.scripts_bucket_arn != "" ? [{
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.scripts_bucket_arn
      }] : [],

      # KMS key permissions for bucket encryption
      var.default_region_buckets["wordpress_media"].enabled && var.kms_key_arn != null && var.kms_key_arn != "" ? [{
        Effect   = "Allow",
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"],
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
# checkov:skip=CKV_AWS_290:Wildcard resource is required for dynamically created log groups by CloudWatch Agent
# checkov:skip=CKV_AWS_355:Wildcard resource is required for dynamically created log groups by CloudWatch Agent
# tfsec:ignore:aws-iam-no-policy-wildcards CloudWatch logs require wildcard permissions to allow dynamic log group creation for WordPress components
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${var.name_prefix}-cloudwatch-logs-policy"
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

# --- SSM Access Policy --- #
# Enables ASG instances to be managed via AWS Systems Manager (SSM), allowing secure remote management.
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.asg_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- WordPress Instance Access Policy --- #
# Allows ASG instances to retrieve database credentials from AWS Secrets Manager.
resource "aws_iam_policy" "wordpress_instance_policy" {
  name        = "${var.name_prefix}-wordpress-instance-policy"
  description = "Allows WordPress instances to retrieve database credentials from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.wordpress_secrets_arn
      }
    ]
  })
}

# Attach WordPress instance policy to the role
resource "aws_iam_role_policy_attachment" "wordpress_instance_policy_attachment" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.wordpress_instance_policy.arn
}

# --- Redis AUTH Secret Access Policy --- #
# Allows ASG instances to retrieve Redis AUTH token from AWS Secrets Manager.
resource "aws_iam_policy" "redis_auth_policy" {
  name        = "${var.name_prefix}-redis-auth-policy"
  description = "Allows WordPress instances to retrieve Redis AUTH token from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.redis_auth_secret_arn
      }
    ]
  })
}

# Attach Redis AUTH policy to the role only if ARN is provided
resource "aws_iam_role_policy_attachment" "redis_auth_policy_attachment" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.redis_auth_policy.arn
}

# --- KMS Decryption Policy --- #
# This policy is created only if at least one KMS-based workflow is enabled:
# - EBS encryption (enable_ebs_encryption = true)
# - WordPress media (var.buckets["wordpress_media"].enabled = true)
# - scripts (var.buckets["scripts"].enabled = true) if using SSE-KMS
resource "aws_iam_policy" "kms_decrypt_policy" {
  count = (
    var.enable_ebs_encryption
    || var.default_region_buckets["wordpress_media"].enabled
    || var.default_region_buckets["scripts"].enabled
  ) ? 1 : 0

  name        = "${var.name_prefix}-kms-decrypt-policy"
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
    || var.default_region_buckets["wordpress_media"].enabled
    || var.default_region_buckets["scripts"].enabled
  ) ? 1 : 0

  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy[0].arn
}

# --- IAM Instance Profile --- #
# Links the IAM role to ASG instances for accessing AWS services.
resource "aws_iam_instance_profile" "asg_instance_profile" {
  name = "${var.name_prefix}-asg-instance-profile"
  role = aws_iam_role.asg_role.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-asg-instance-profile"
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
#    - A dedicated IAM policy grants ASG instances read-only access (Get/Describe) to the 
#      specified secret in AWS Secrets Manager.
#    - This avoids storing raw passwords in Terraform variables and leverages AWS-native
#      secrets management.
#    - Two separate policies are created for WordPress secrets and Redis AUTH token:
#      * wordpress_instance_policy: Always created, grants access to WordPress secrets
#      * redis_auth_policy: Provides access to Redis AUTH token secret