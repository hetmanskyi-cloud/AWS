# --- CloudTrail Configuration --- #
# Configures AWS CloudTrail for comprehensive API activity logging:
# - Writes logs to a centralized S3 bucket with KMS encryption
# - Integrates with CloudWatch Logs for real-time monitoring
# - Validates log file integrity for security

# --- Main CloudTrail Configuration --- #
# Creates the main CloudTrail instance for API activity monitoring
resource "aws_cloudtrail" "cloudtrail" {
  # Basic trail configuration
  name           = "${var.name_prefix}-cloudtrail"
  s3_bucket_name = module.s3.logging_bucket_id
  s3_key_prefix  = "cloudtrail"
  enable_logging = true

  # Security settings
  enable_log_file_validation = true
  kms_key_id                 = module.kms.kms_key_arn

  # Event settings
  include_global_service_events = true
  # This CloudTrail is configured for a single region. Multi-region logging is not required for this use case.
  is_multi_region_trail = false # tfsec:ignore:aws-cloudtrail-enable-all-regions

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  # Resource tags
  tags = {
    Name        = "${var.name_prefix}-cloudtrail"
    Environment = var.environment
  }
}

# --- CloudWatch Logs Configuration --- #
# Configures the CloudWatch Log Group for CloudTrail events
resource "aws_cloudwatch_log_group" "cloudtrail" {
  # Log group settings
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = 30
  kms_key_id        = module.kms.kms_key_arn

  # Resource tags
  tags = {
    Name        = "${var.name_prefix}-cloudtrail"
    Environment = var.environment
  }
}

# --- IAM Configuration for CloudWatch Integration --- #
# Creates the IAM role that allows CloudTrail to send logs to CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.name_prefix}-cloudtrail-cloudwatch"

  # Trust relationship policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Resource tags
  tags = {
    Name        = "${var.name_prefix}-cloudtrail-cloudwatch"
    Environment = var.environment
  }
}

# --- IAM Policy for CloudWatch Access --- #
# Defines permissions for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.name_prefix}-cloudtrail-cloudwatch"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  # Policy definition
  # tfsec:ignore:aws-iam-no-policy-wildcards
  # The wildcard is necessary because CloudTrail dynamically creates log streams.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}