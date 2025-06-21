# --- IAM Role for CloudFront Firehose Delivery Streams (us-east-1) --- #
# This role is required for Kinesis Firehose to deliver CloudFront WAF logs to S3.
# All CloudFront Firehose/IAM resources must be created in us-east-1 (provider = aws.cloudfront).
resource "aws_iam_role" "cloudfront_firehose_role" {
  provider = aws.cloudfront
  count    = var.enable_cloudfront_firehose ? 1 : 0

  name = "${var.name_prefix}-cloudfront-firehose-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-firehose-role-${var.environment}"
  })
}

# --- IAM Policy for CloudFront Firehose Delivery Streams (us-east-1) --- #
# Grants CloudFront Firehose permissions to write logs to the S3 logging bucket and use the KMS key for encryption.
resource "aws_iam_policy" "cloudfront_firehose_policy" {
  provider = aws.cloudfront
  count    = var.enable_cloudfront_firehose ? 1 : 0

  name = "${var.name_prefix}-cloudfront-firehose-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",         # Grants Firehose the ability to put logs into the S3 bucket
          "s3:GetBucketLocation", # Allows Firehose to get the location of the bucket
          "s3:ListBucket"         # Allows Firehose to list the bucket contents for logging
        ],
        Resource = [
          "${var.logging_bucket_arn}/*", # Permission to write to all objects inside the bucket
          var.logging_bucket_arn         # Permission to access the bucket itself
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",          # Allow encryption with KMS
          "kms:Decrypt",          # Allow decryption of objects with KMS
          "kms:ReEncrypt*",       # Allows re-encryption of data
          "kms:GenerateDataKey*", # Allows generating encryption keys for Firehose
          "kms:DescribeKey"       # Allows Firehose to describe the KMS key
        ],
        Resource = var.kms_key_arn # Specifies the KMS key for encryption and decryption
      },
      {
        # This permission allows Firehose to write error logs to CloudWatch if data delivery to S3 fails.
        # It requires the corresponding log group to exist.
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents" # Allows Firehose to send logs to CloudWatch for error tracking
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/*:log-stream:*" # Logs for Firehose error events
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-firehose-policy-${var.environment}"
  })
}

# --- IAM Role Policy Attachment (us-east-1, CloudFront) --- #
# Attaches the CloudFront Firehose policy to the Firehose role in us-east-1.
resource "aws_iam_role_policy_attachment" "cloudfront_firehose_policy_attachment" {
  provider   = aws.cloudfront
  count      = var.enable_cloudfront_firehose ? 1 : 0
  role       = aws_iam_role.cloudfront_firehose_role[0].name
  policy_arn = aws_iam_policy.cloudfront_firehose_policy[0].arn
}

# --- CloudWatch Log Group for Firehose Error Logging (us-east-1) --- #
# This resource creates a dedicated CloudWatch Log Group for Kinesis Firehose delivery error logging.
# It is required by the logs:PutLogEvents permission in the IAM policy above to ensure robust error handling.
resource "aws_cloudwatch_log_group" "cloudfront_firehose_log_group" {
  provider = aws.cloudfront
  count    = var.enable_cloudfront_firehose ? 1 : 0

  # The name must follow the pattern /aws/kinesisfirehose/<delivery-stream-name>
  name              = "/aws/kinesisfirehose/${var.name_prefix}-cloudfront-waf-logs-firehose-${var.environment}"
  retention_in_days = 7 # A reasonable retention period for error logs.

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-waf-logs-firehose-log-group-${var.environment}"
  })
}

# --- Notes --- #
# 1. All CloudFront Firehose IAM resources are created only in us-east-1 via provider = aws.cloudfront.
# 2. No IAM roles or policies for CloudFront Firehose are created in the default region in this module.
# 3. This avoids regional confusion and is required for proper CloudFront WAF logging.
# 4. IAM policy uses least privilege: only required S3/KMS/CloudWatch Logs actions are allowed.
# 5. All resource names and tags use the project and environment naming convention for clarity per environment.