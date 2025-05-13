# --- CloudTrail Configuration --- #
# Configures AWS CloudTrail for comprehensive API activity logging:
# - Writes logs to a centralized S3 bucket with KMS encryption
# - Integrates with CloudWatch Logs for real-time monitoring
# - Validates log file integrity for security

# --- CloudTrail S3 Bucket Policy --- #
# Defines the required S3 bucket policy for CloudTrail to store logs.
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0

  bucket = module.s3.cloudtrail_bucket_id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Allow CloudTrail to check bucket ACL (required for log delivery)
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = module.s3.cloudtrail_bucket_arn
      },
      # Allow CloudTrail to write logs to the S3 bucket
      # Note: CloudTrail requires the ACL "bucket-owner-full-control" on PutObject requests.
      # This is a known AWS requirement for successful log delivery.
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${module.s3.cloudtrail_bucket_arn}/cloudtrail/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # Ensure that CloudTrail can list objects for validation
      {
        Sid       = "AWSCloudTrailList"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:ListBucket"
        Resource  = module.s3.cloudtrail_bucket_arn
      },
      # Enforce HTTPS-only access for security compliance
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          module.s3.cloudtrail_bucket_arn,
          "${module.s3.cloudtrail_bucket_arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Prevent unnecessary updates due to JSON formatting differences
  lifecycle {
    ignore_changes = [policy]
  }

  # Ensure the policy is applied only after the S3 module is created
  depends_on = [module.s3]
}

# --- Main CloudTrail Configuration --- #
# Creates the main CloudTrail instance for API activity monitoring
# Only create CloudTrail if logging bucket is enabled
# tfsec:ignore:aws-cloudtrail-enable-all-regions
resource "aws_cloudtrail" "cloudtrail" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0

  # Basic trail configuration
  name           = "${var.name_prefix}-cloudtrail"
  s3_bucket_name = module.s3.cloudtrail_bucket_name
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

  # Sends CloudTrail events to the CloudTrail-specific SNS topic for notifications. 
  sns_topic_name = aws_sns_topic.cloudtrail_events[0].name

  tags_all = merge(local.tags_cloudtrail, {
    Name = "${var.name_prefix}-cloudtrail"
  })

  # Make sure the bucket policy is applied before CloudTrail is created
  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

# --- CloudWatch Logs Configuration --- #
# Configures the CloudWatch Log Group for CloudTrail events
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0

  # Log group settings
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.cloudtrail_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false # Allows this log group to be destroyed by Terraform

  tags_all = merge(local.tags_cloudtrail, {
    Name = "${var.name_prefix}-cloudtrail-log-group"
  })
}

# --- IAM Configuration for CloudWatch Integration --- #
# Creates the IAM role that allows CloudTrail to send logs to CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0

  name = "${var.name_prefix}-cloudtrail-cloudwatch"

  # Trust relationship policy
  # Note: Ensure CloudTrail has permissions to use the KMS key (module.kms).
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

  tags_all = merge(local.tags_cloudtrail, {
    Name = "${var.name_prefix}-cloudtrail-cloudwatch"
  })
}

# --- IAM Policy for CloudWatch Access --- #
# Defines permissions for CloudTrail to write to CloudWatch Logs
# tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0

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
# 1. CloudTrail Logging:
#    - Logs API activity to a dedicated "cloudtrail" bucket if enabled.
#    - Uses KMS encryption (via module.kms.kms_key_arn) for logs at rest.
#    - Validates log integrity to detect unauthorized changes.
#
# 2. Conditional Creation:
#    - The CloudTrail instance, IAM roles, and CloudWatch Log Group
#      are only created if var.default_region_buckets["cloudtrail"].enabled = true.
#
# 3. CloudWatch Integration:
#    - Logs are sent to CloudWatch for near real-time monitoring.
#    - Requires an IAM role (cloudtrail_cloudwatch) with permissions to write logs.
#
# 4. Multi-Region Logging:
#    - Disabled (is_multi_region_trail = false) because we only need
#      single-region logs in this environment.
#    - In production, you may enable multi-region logging for compliance.
#
# 5. Retention & Security:
#    - CloudWatch logs are retained for the specified retention_in_days (default 30).
#    - The log group is KMS-encrypted for additional security (module.kms).
#
# 6. Best Practices:
#    - Enable multi-region logging if required by compliance or for broader coverage.
#    - Use restricted IAM permissions for better security.
#    - Regularly audit CloudTrail logs for unusual activity.