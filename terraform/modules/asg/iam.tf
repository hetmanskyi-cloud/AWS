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

# --- Local Variables ---
# Define a flag indicating whether any S3 bucket is enabled.
# This flag is set to true if either the WordPress media bucket or the scripts bucket
# is enabled in the 'buckets' map from terraform.tfvars.
locals {
  s3_enabled = lookup(var.buckets, "wordpress_media", false) || lookup(var.buckets, "scripts", false)
}

# --- S3 Access Policy --- #
resource "aws_iam_policy" "s3_access_policy" {
  count = local.s3_enabled ? 1 : 0

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
        Resource = local.s3_enabled
      }
    ]
  })
}

# Attach S3 access policy to the role only if policy was created
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  count = local.s3_enabled ? 1 : 0

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
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.wordpress_secret_name}"
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