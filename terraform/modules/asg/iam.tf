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

# --- Local Variables --- #
# Define S3 resources array that combines WordPress media bucket (if enabled)
# and scripts bucket (if provided) ARNs with their object paths (/*).
locals {
  # Combine S3 resources for WordPress media (conditional) and scripts bucket (if provided)
  asg_s3_resources = concat(
    lookup(var.buckets, "wordpress_media", false) && var.wordpress_media_bucket_arn != null ?
    ["${var.wordpress_media_bucket_arn}", "${var.wordpress_media_bucket_arn}/*"] : [],
    var.scripts_bucket_arn != null && var.scripts_bucket_arn != "" ?
    ["${var.scripts_bucket_arn}", "${var.scripts_bucket_arn}/*"] : []
  )
}

# --- S3 Access Policy --- #
resource "aws_iam_policy" "s3_access_policy" {
  count = length(local.asg_s3_resources) > 0 ? 1 : 0

  name        = "${var.name_prefix}-asg-s3-access-policy"
  description = "S3 access policy for WordPress media (if enabled) and deployment scripts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = local.asg_s3_resources
      }
    ]
  })
}

# Attach S3 access policy to the role only if policy was created
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  count = length(local.asg_s3_resources) > 0 ? 1 : 0

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
# Allows ASG instances to decrypt S3 objects and EBS volumes encrypted with KMS.
resource "aws_iam_policy" "kms_decrypt_policy" {
  name        = "${var.name_prefix}-kms-decrypt-policy"
  description = "Allows EC2 instances to decrypt S3 objects and EBS volumes encrypted with KMS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Grant full decryption and key description permissions for KMS
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Attach the KMS decryption policy to the ASG IAM role to allow access to encrypted S3 objects and EBS volumes
resource "aws_iam_role_policy_attachment" "kms_access" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy.arn
}

# --- ElastiCache Access Policy --- #
# Grants ASG instances permissions to query Redis endpoints
resource "aws_iam_policy" "elasticache_access_policy" {
  name        = "${var.name_prefix}-elasticache-access-policy"
  description = "Allows ASG instances to describe ElastiCache replication groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeCacheClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ElastiCache policy to ASG IAM role
resource "aws_iam_role_policy_attachment" "elasticache_access" {
  role       = aws_iam_role.asg_role.name
  policy_arn = aws_iam_policy.elasticache_access_policy.arn
}

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