# --- CloudTrail Configuration --- #
# Configures AWS CloudTrail for comprehensive API activity logging:
# - Writes logs to a centralized S3 bucket with KMS encryption
# - Integrates with CloudWatch Logs for real-time monitoring
# - Validates log file integrity for security

# --- CloudTrail S3 Bucket Policy --- #
# Explicitly set the S3 bucket policy required by CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  bucket = module.s3.logging_bucket_id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = module.s3.logging_bucket_arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${module.s3.logging_bucket_arn}/cloudtrail/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          module.s3.logging_bucket_arn,
          "${module.s3.logging_bucket_arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Ignore changes to policy to avoid constant updates due to JSON formatting differences
  lifecycle {
    ignore_changes = [policy]
  }

  # Explicitly depend on the S3 module
  depends_on = [module.s3]
}

# --- Main CloudTrail Configuration --- #
# Creates the main CloudTrail instance for API activity monitoring
# Only create CloudTrail if logging bucket is enabled
# tfsec:ignore:aws-cloudtrail-enable-all-regions
resource "aws_cloudtrail" "cloudtrail" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  # Basic trail configuration
  name           = "${var.name_prefix}-cloudtrail"
  s3_bucket_name = module.s3.logging_bucket_name
  s3_key_prefix  = "cloudtrail"
  enable_logging = true

  # Security settings
  enable_log_file_validation = true
  kms_key_id                 = module.kms.kms_key_arn

  # Event settings
  include_global_service_events = true

  # This CloudTrail is configured for a single region. Multi-region logging is not required for this use case.
  is_multi_region_trail = false

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch[0].arn

  # Resource tags
  tags = {
    Name        = "${var.name_prefix}-cloudtrail"
    Environment = var.environment
  }

  # Make sure the bucket policy is applied before CloudTrail is created
  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

# --- CloudWatch Logs Configuration --- #
# Configures the CloudWatch Log Group for CloudTrail events
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  # Log group settings
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.cloudtrail_logs_retention_in_days
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
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

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
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  name = "${var.name_prefix}-cloudtrail-cloudwatch"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  # Policy definition  
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
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

# --- Notes --- #
# 1. **CloudTrail Logging:** 
#    - Logs API activity to an S3 bucket (`logging bucket`) if enabled.
#    - Uses KMS encryption to secure logs at rest.
#    - Validates log integrity to detect unauthorized changes.
#
# 2. **Conditional Creation:** 
#    - The CloudTrail instance, IAM roles, and CloudWatch Log Group are **only created if the logging bucket exists**.
#    - This prevents errors in environments where CloudTrail logging is not required.
#
# 3. **CloudWatch Integration:** 
#    - Logs are sent to CloudWatch for real-time monitoring.
#    - Requires an IAM role (`cloudtrail_cloudwatch`) with permissions to write logs.
#
# 4. **IAM Policies:**
#    - `aws_iam_role_policy.cloudtrail_cloudwatch` allows CloudTrail to send logs to CloudWatch.
#    - The `tfsec:ignore` directive is used to suppress wildcard warnings because CloudTrail dynamically creates log streams.
#
# 5. **Multi-Region Logging:**
#    - Disabled (`is_multi_region_trail = false`) because this CloudTrail is only needed in the current AWS region.
#    - In production, enable multi-region logging if needed for security compliance.
#
# 6. **Retention & Security:**
#    - CloudWatch logs are retained for **30 days**.
#    - The log group is **KMS-encrypted** for additional security.
#
# 7. **Best Practices:**
#    - Enable **multi-region logging** in production environments.
#    - Use **restricted IAM permissions** for better security.
#    - Regularly **audit CloudTrail logs** for unusual activity.