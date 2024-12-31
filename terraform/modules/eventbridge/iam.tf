# --- IAM Configuration for EventBridge --- #
# This file defines IAM roles and policies required for EventBridge to:
# - Access S3 buckets for AMI metadata and deployment scripts.
# - Manage EC2 instances and Auto Scaling Groups (ASG).
# The configuration is enabled only for stage/prod environments.

# --- IAM Role for EventBridge --- #
# Allows EventBridge to assume permissions for invoking tasks and accessing resources.
resource "aws_iam_role" "eventbridge_role" {
  count = var.environment != "dev" ? 1 : 0 # Role is created only in stage/prod

  name = "${var.name_prefix}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-eventbridge-role"
    Environment = var.environment
  }
}

# --- S3 Access Policy for EventBridge --- #
# Grants read access to specified S3 buckets for deployment scripts and AMI metadata.
resource "aws_iam_policy" "s3_access_policy" {
  count = var.environment != "dev" ? 1 : 0 # Policy is created only in stage/prod

  name        = "${var.name_prefix}-eventbridge-s3-access"
  description = "Allows EventBridge to access S3 buckets for scripts and AMI metadata"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource : [
          "${var.scripts_bucket_arn}",
          "${var.scripts_bucket_arn}/*",
          "${var.ami_bucket_arn}",
          "${var.ami_bucket_arn}/*"
        ]
      }
    ]
  })
}

# --- EC2 and ASG Policies --- #
# Grants permissions to manage EC2 instances and update ASG configurations.
resource "aws_iam_policy_attachment" "eventbridge_ec2_asg" {
  count = var.environment != "dev" ? 1 : 0 # Policy is attached only in stage/prod

  name       = "${var.name_prefix}-eventbridge-ec2-asg-access"
  roles      = [aws_iam_role.eventbridge_role[0].name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# --- Attach S3 Policy to EventBridge Role --- #
# Attaches the S3 access policy to the EventBridge role.
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  count = var.environment != "dev" ? 1 : 0 # Policy is attached only in stage/prod

  role       = aws_iam_role.eventbridge_role[0].name
  policy_arn = aws_iam_policy.s3_access_policy[0].arn
}

# --- Notes --- #
# 1. **S3 Permissions**:
#    - Grants read access to `scripts_bucket` for deployment scripts.
#    - Grants read access to `ami_bucket` for fetching AMI metadata.
#
# 2. **EC2 and ASG Permissions**:
#    - Policy allows EventBridge to manage EC2 instances and Auto Scaling Groups (ASG).
#    - This includes starting, stopping, and modifying instances as part of workflows.
#
# 3. **Environment Logic**:
#    - The IAM role and policies are created only in `stage` and `prod` environments.
#    - Resources are disabled in `dev` to avoid unnecessary costs and complexity.
#
# 4. **Security Best Practices**:
#    - Validate bucket ARNs (`scripts_bucket_arn`, `ami_bucket_arn`) before deployment.
#    - Use least privilege by granting minimal permissions to EventBridge.
#    - Review IAM policies periodically for compliance with organizational security standards.