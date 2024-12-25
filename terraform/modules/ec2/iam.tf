# --- IAM Configuration for EC2 Instances --- #
# This file defines the IAM role and policies for EC2 instances, including:
# - S3 access for AMI, scripts, and media.
# - CloudWatch logging.
# - Systems Manager (SSM) for management without SSH.
# Temporary credentials are managed automatically via AWS and accessed through IMDSv2.

# --- IAM Role --- #
# Allows EC2 instances to assume specific permissions for accessing AWS services.
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"

  # Trust policy for EC2 service
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

# --- S3 Access Policy --- #
# Local variable to define S3 resources for EC2 instances.
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

# Policy for accessing S3 buckets
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

# --- CloudWatch Access Policy --- #
# Enables EC2 instances to publish metrics and logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# --- SSM Access Policy --- #
# Enables EC2 instances to be managed via AWS Systems Manager (SSM).
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Attach S3 Policy --- #
# Attaches the S3 access policy to the EC2 role.
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# --- IAM Instance Profile --- #
# Links the IAM role to EC2 instances for accessing AWS services.
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.name_prefix}-ec2-instance-profile"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. Temporary credentials:
#    - Automatically managed via AWS IAM.
#    - Accessible through IMDSv2 with a validity of 1 hour (rotated automatically).
# 2. S3 access:
#    - AMI bucket: Read-only for fetching metadata.
#    - Media bucket: Full access (stage/prod only).
#    - Scripts bucket: Full access for configuration scripts.
# 3. SSM policy:
#    - Provides secure management of EC2 instances without requiring SSH access.
# 4. CloudWatch policy:
#    - Enables detailed monitoring by publishing metrics and logs to CloudWatch.
# 5. Instance profile:
#    - Shared across all EC2 instances, ensuring consistent access to AWS services.
# 6. Best practices:
#    - Review S3 bucket permissions regularly to minimize access.
#    - Rotate IAM roles periodically to comply with security standards.