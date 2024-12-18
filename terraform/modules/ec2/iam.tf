# --- IAM Configuration for EC2 Instances --- #
# This file defines the IAM role and policies associated with EC2 instances.
# Policies include permissions for S3 access, CloudWatch, and SSM permissions.

# IAM Role for EC2 instances
# This role allows EC2 instances to assume specific permissions for accessing AWS services.
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-ec2-role"
    Environment = var.environment
  }
}

# --- S3 Access Policy for EC2 --- #
# Local variable to define S3 resources for access control.
# Media bucket and AMI bucket are included; scripts bucket is always required.
locals {
  ec2_s3_resources = compact([
    var.environment != "dev" && var.wordpress_media_bucket_arn != null ? "${var.wordpress_media_bucket_arn}" : null,
    var.environment != "dev" && var.wordpress_media_bucket_arn != null ? "${var.wordpress_media_bucket_arn}/*" : null,
    "${var.scripts_bucket_arn}",
    "${var.scripts_bucket_arn}/*",
    "${var.ami_bucket_arn}",
    "${var.ami_bucket_arn}/*"
  ])
}

# S3 Policy for EC2 instances
# Grants access to specific S3 buckets for media, scripts, and AMI retrieval.
resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.name_prefix}-s3-access-policy"
  description = "S3 access policy for EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          "${var.ami_bucket_arn}",
          "${var.ami_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
        Resource = local.ec2_s3_resources
      }
    ]
  })
}

# --- CloudWatch Access Policy for Logging and Monitoring --- #
# Provides permissions for EC2 instances to publish metrics and logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# --- SSM Access Policy for EC2 Management --- #
# Provides permissions for EC2 instances to be managed via AWS Systems Manager.
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Attach S3 Policy to Role --- #
# Attaches the S3 access policy to the EC2 role.
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# --- IAM Instance Profile for EC2 --- #
# The instance profile that links the IAM role to the EC2 instance.
# Used for both Auto Scaling Group and the single instance in dev.
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.name_prefix}-ec2-instance-profile"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. S3 access policies:
#    - AMI bucket: Read-only permissions for fetching AMI metadata.
#    - Media and scripts buckets: Full access for storing and retrieving assets.
# 2. SSM policy ensures complete management capabilities for all EC2 instances.
# 3. CloudWatch policy allows EC2 instances to publish logs and metrics for detailed monitoring.
# 4. Instance profile is shared across all EC2 instances in the project, ensuring consistency.