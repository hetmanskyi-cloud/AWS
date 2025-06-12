# --- Firehose Delivery Stream for ALB WAF Logs --- #
# This resource creates a Firehose delivery stream to process and deliver ALB WAF logs to an S3 bucket.
# Controlled by the `enable_firehose` variable to enable or disable all related resources.
resource "aws_kinesis_firehose_delivery_stream" "aws_alb_waf_logs" { # <--- ИЗМЕНЕНО ЗДЕСЬ!
  count = var.enable_firehose ? 1 : 0

  name        = "${var.name_prefix}-alb-waf-logs-${var.environment}" # Specific name for ALB WAF logs
  destination = "extended_s3"                                        # Destination is an S3 bucket with extended configuration.

  # Extended S3 Configuration
  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role[0].arn  # IAM Role for Firehose permissions.
    bucket_arn = var.logging_bucket_arn             # Target S3 bucket for logs.
    prefix     = "${var.name_prefix}/alb-waf-logs/" # Dedicated prefix for ALB WAF logs

    # These buffering settings represent a default configuration suitable for testing.
    # For production, these values should be adjusted based on anticipated log volume and delivery latency requirements.
    buffering_interval = 300 # Buffering interval in seconds.
    buffering_size     = 5   # Buffering size in MB.

    # GZIP compression reduces storage costs but may increase processing costs when decrypting data in the future.
    compression_format = "GZIP" # Compress logs in GZIP format to reduce S3 storage costs. Note: decompression may add processing overhead when analyzing logs later.

    # checkov:skip=CKV_AWS_240:Encryption is configured inside extended_s3_configuration with kms_key_arn
    # checkov:skip=CKV_AWS_241:Using Customer Managed Key defined in kms_key_arn
    kms_key_arn = module.kms.kms_key_arn # KMS key (Customer Managed Key) for encrypting logs. Ensures secure storage in S3.
  }

  tags = merge(local.common_tags, local.tags_firehose, {
    Name = "${var.name_prefix}-firehose-alb-waf-logs-${var.environment}"
  })
}

# --- Firehose Delivery Stream for CloudFront WAF Logs --- #
# This new resource creates a separate Firehose delivery stream for CloudFront WAF logs.
# This ensures distinct prefixes and easier management for different WAF log types.
resource "aws_kinesis_firehose_delivery_stream" "aws_cloudfront_waf_logs" {
  count = var.enable_firehose && var.enable_cloudfront_waf_logging ? 1 : 0 # Only create if Firehose is enabled AND CloudFront WAF logging is enabled

  name        = "${var.name_prefix}-cloudfront-waf-logs-${var.environment}" # Specific name for CloudFront WAF logs
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role[0].arn
    bucket_arn = var.logging_bucket_arn
    prefix     = "${var.name_prefix}/cloudfront-waf-logs/" # Dedicated prefix for CloudFront WAF logs

    buffering_interval = 300
    buffering_size     = 5
    compression_format = "GZIP"
    kms_key_arn        = module.kms.kms_key_arn
  }

  tags = merge(local.common_tags, local.tags_firehose, {
    Name = "${var.name_prefix}-firehose-cloudfront-waf-logs-${var.environment}"
  })

  depends_on = [
    aws_iam_role.firehose_role # Ensure role is created first
  ]
}


# --- IAM Role for Firehose --- #
# This IAM Role is required for Firehose to deliver logs to the target S3 bucket.
# Ensure it has only the minimum necessary permissions (least privilege principle).
resource "aws_iam_role" "firehose_role" {
  count = var.enable_firehose ? 1 : 0

  name = "${var.name_prefix}-firehose-role${var.environment}"

  # Policy for assuming the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, local.tags_firehose, {
    Name = "${var.name_prefix}-firehose-role-${var.environment}"
  })
}

# --- IAM Policy for Firehose --- #
# This policy defines the permissions required by Firehose to interact with the S3 bucket.
# This single policy is sufficient for both ALB WAF and CloudFront WAF Firehose streams.
resource "aws_iam_policy" "firehose_policy" {
  count = var.enable_firehose ? 1 : 0

  name = "${var.name_prefix}-firehose-policy${var.environment}"

  # Policy details.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ],
        # Resources apply to the logging bucket and ALL its contents.
        # This covers both 'alb-waf-logs' and 'cloudfront-waf-logs' prefixes.
        Resource = [
          "${var.logging_bucket_arn}/*", # Applies to all objects in the logging bucket.
          var.logging_bucket_arn         # Applies to the bucket itself.
        ]
      },
      { # Permission to encrypt using KMS
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = module.kms.kms_key_arn
      },
      # Add CloudWatch Logs permissions for Firehose to send error logs, if needed
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/*:log-stream:*"
      }
    ]
  })

  tags = merge(local.common_tags, local.tags_firehose, {
    Name = "${var.name_prefix}-firehose-policy-${var.environment}"
  })
}

# --- IAM Role Policy Attachment --- #
# Attaches the IAM policy to the Firehose role.
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  count = var.enable_firehose ? 1 : 0

  role       = aws_iam_role.firehose_role[0].name
  policy_arn = aws_iam_policy.firehose_policy[0].arn
}

# --- Notes --- #
# 1. All Firehose-related resources are controlled by the `enable_firehose` variable.
# 2. Separate Firehose streams are used for ALB WAF and CloudFront WAF logs
#    to allow for distinct prefixes (folders) in the S3 logging bucket.
# 3. Logs are delivered to an S3 bucket with GZIP compression for storage efficiency.
# 4. S3 is chosen over CloudWatch Logs for its cost-effectiveness and flexibility in long-term storage.
#    For small projects, this is the optimal solution. If the project scales, consider CloudWatch Logs
#    for real-time monitoring, but be mindful of the additional costs.
# 5. KMS encryption ensures logs are securely stored in the target bucket.
# 6. The logging bucket is dynamically assigned based on the logging_bucket_arn variable.
# 7. Buffering settings (interval and size) control how often Firehose delivers logs to S3.
#    - Adjust these values based on log volume and latency requirements.
# 8. A single IAM role and policy are used for both Firehose streams,
#    as the policy grants permissions to the entire logging bucket.