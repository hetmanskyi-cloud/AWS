# --- IAM Configuration for ASG Instances --- #
# This file defines the IAM role and policies for ASG instances, including:
# - Conditional S3 access (WordPress media and deployment scripts).
# - CloudWatch logging.
# - Systems Manager (SSM) for management without SSH.
# - KMS decryption for S3 and EBS encryption.
# Temporary credentials are managed automatically via AWS and accessed through IMDSv2.

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

  tags = {
    Name        = "${var.name_prefix}-asg-role"
    Environment = var.environment
  }
}

# --- S3 Access Policy ---
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
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.wordpress_secret_name}"
      }
    ]
  })
}

# Attach WordPress instance policy to the role
resource "aws_iam_role_policy_attachment" "wordpress_instance_policy_attachment" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.wordpress_instance_policy.arn
}

# --- IAM Instance Profile --- #
# Links the IAM role to ASG instances for accessing AWS services.
resource "aws_iam_instance_profile" "asg_instance_profile" {
  name = "${var.name_prefix}-asg-instance-profile"
  role = aws_iam_role.asg_role.name

  tags = {
    Name        = "${var.name_prefix}-asg-instance-profile"
    Environment = var.environment
  }
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

      # 3) EBS encryption => typically Decrypt/DescribeKey is enough
      var.enable_ebs_encryption
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

# Add data sources for current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- Notes --- #
# 1. Temporary credentials:
#    - Automatically managed via AWS IAM.
#    - Accessible through IMDSv2 with a validity of 1 hour (rotated automatically).
#
# 2. S3 access:
#    - S3 access policy is created only if there are valid S3 resources defined.
#    - WordPress media bucket access is conditional, based on `buckets` variable.
#    - Scripts bucket access depends on scripts_bucket_arn being provided.
#
# 3. SSM policy:
#    - Provides secure management of ASG instances without requiring SSH access.
#
# 4. CloudWatch policy:
#    - Enables detailed monitoring by publishing metrics and logs to CloudWatch.
#
# 5. KMS policy:
#    - Grants permissions to decrypt objects in S3 and EBS volumes.
#    - Ensures the instance can read encrypted data securely.
#
# 6. Instance profile:
#    - Shared across all ASG instances, ensuring consistent access to AWS services.
#
# 7. Best practices:
#    - Review S3 bucket permissions regularly to minimize access.
#    - Rotate IAM roles periodically to comply with security standards.
#
# 8. Security considerations:
#    - Use conditional policy creation to avoid empty resource lists.
#    - Ensure fine-grained access to avoid privilege escalation.
#    - Enable CloudTrail logging for IAM actions to track access.