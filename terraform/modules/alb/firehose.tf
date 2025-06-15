# --- ALB Firehose Delivery Stream --- #
# This resource creates a Firehose delivery stream to process and deliver WAF logs to an S3 bucket.
# Controlled by the `enable_firehose` variable to enable or disable all related resources.
resource "aws_kinesis_firehose_delivery_stream" "firehose_alb_waf_logs" {
  count = var.enable_alb_firehose ? 1 : 0

  # NOTE: The delivery stream name MUST start with "aws-waf-logs-" 
  # because AWS WAF requires it for logging configuration. 
  # Otherwise, PutLoggingConfiguration will fail with "The ARN isn't valid".
  name = "aws-waf-logs-${var.name_prefix}-alb-firehose-${var.environment}"

  destination = "extended_s3" # Destination is an S3 bucket with extended configuration.

  # Extended S3 Configuration
  extended_s3_configuration {
    role_arn   = aws_iam_role.alb_firehose_role[0].arn # IAM Role for Firehose permissions.
    bucket_arn = var.logging_bucket_arn                # Target S3 bucket for logs.
    prefix     = "${var.name_prefix}/alb-waf-logs/"    # Prefix for organizing WAF logs in the bucket.

    # CloudWatch logging is disabled by default.
    # If enabled, logs will be sent to CloudWatch Logs for monitoring.
    # This can be useful for real-time monitoring but may incur additional costs.
    # Note: Enabling CloudWatch logging requires additional IAM permissions.
    dynamic "cloudwatch_logging_options" {
      for_each = var.enable_alb_firehose_cloudwatch_logs && var.enable_alb_firehose ? [1] : []

      content {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/alb-waf-logs"
        log_stream_name = "S3Delivery"
      }
    }

    # These buffering settings represent a default configuration suitable for testing. 
    # For production, these values should be adjusted based on anticipated log volume and delivery latency requirements.
    buffering_interval = 300 # Buffering interval in seconds.
    buffering_size     = 5   # Buffering size in MB.

    # GZIP compression reduces storage costs but may increase processing costs when decrypting data in the future.
    compression_format = "GZIP" # Compress logs in GZIP format to reduce S3 storage costs. Note: decompression may add processing overhead when analyzing logs later.

    # checkov:skip=CKV_AWS_240:Encryption is configured inside extended_s3_configuration with kms_key_arn
    # checkov:skip=CKV_AWS_241:Using Customer Managed Key defined in kms_key_arn
    kms_key_arn = var.kms_key_arn # KMS key (Customer Managed Key) for encrypting logs. Ensures secure storage in S3.
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-firehose-alb-waf-delivery-stream-${var.environment}"
  })
}

# --- IAM Role for ALB Firehose --- #
# This IAM Role is required for ALB Firehose to deliver logs to the target S3 bucket.
# Ensure it has only the minimum necessary permissions (least privilege principle).
resource "aws_iam_role" "alb_firehose_role" {
  count = var.enable_alb_firehose ? 1 : 0

  name = "${var.name_prefix}-alb-firehose-role${var.environment}"

  # Policy for assuming the role
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-firehose-role-${var.environment}"
  })
}

# --- IAM Policy for ALB Firehose --- #
# This policy defines the permissions required by Firehose to interact with the S3 bucket.
resource "aws_iam_policy" "alb_firehose_policy" {
  count = var.enable_alb_firehose ? 1 : 0

  name = "${var.name_prefix}-firehose-policy${var.environment}"

  # Policy details
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
        Resource = compact([
          var.logging_bucket_arn != null ? "${var.logging_bucket_arn}/*" : null, # Applies to all objects in the logging bucket.
          var.logging_bucket_arn != null ? var.logging_bucket_arn : null,        # Applies to the bucket itself.
        ])
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
        Resource = var.kms_key_arn
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-firehose-policy-${var.environment}"
  })
}

# --- IAM Role Policy Attachment --- #
# Attaches the IAM policy to the ALB Firehose role.
resource "aws_iam_role_policy_attachment" "alb_firehose_policy_attachment" {
  count = var.enable_alb_firehose ? 1 : 0

  role       = aws_iam_role.alb_firehose_role[0].name
  policy_arn = aws_iam_policy.alb_firehose_policy[0].arn
}

# IAM Policy for allowing Kinesis Firehose to log to CloudWatch
resource "aws_iam_policy" "alb_firehose_cw_policy" {
  count       = var.enable_alb_firehose_cloudwatch_logs && var.enable_alb_firehose ? 1 : 0
  name        = "${var.name_prefix}-alb-firehose-cw-policy-${var.environment}"
  description = "Allows Kinesis Firehose to log delivery errors to CloudWatch Logs"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the Firehose role
resource "aws_iam_role_policy_attachment" "alb_firehose_cw_attach" {
  count      = var.enable_alb_firehose_cloudwatch_logs && var.enable_alb_firehose ? 1 : 0
  role       = aws_iam_role.alb_firehose_role[0].name
  policy_arn = aws_iam_policy.alb_firehose_cw_policy[0].arn
}

# --- Notes --- #
# 1. All ALB Firehose-related resources are controlled by the `enable_alb_firehose` variable.
# 2. Logs are delivered to an S3 bucket with GZIP compression for storage efficiency.
# 3. S3 is chosen over CloudWatch Logs for its cost-effectiveness and flexibility in long-term storage.
#    For small projects, this is the optimal solution. If the project scales, consider CloudWatch Logs
#    for real-time monitoring, but be mindful of the additional costs.
# 4. KMS encryption ensures logs are securely stored in the target bucket.
# 5. The logging bucket is dynamically assigned based on the logging_bucket_arn variable.
# 6. Buffering settings (interval and size) control how often Firehose delivers logs to S3.
#    - Adjust these values based on log volume and latency requirements.