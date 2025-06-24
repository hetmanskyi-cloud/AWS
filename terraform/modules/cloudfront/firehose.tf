# --- Kinesis Firehose Delivery Stream for CloudFront WAF Logs (us-east-1) --- #
# This resource creates an Amazon Kinesis Firehose Delivery Stream to collect
# and deliver AWS WAF logs to a designated S3 bucket.
# All CloudFront WAF-related logging components, including Firehose, must be
# provisioned in the us-east-1 region.

resource "aws_kinesis_firehose_delivery_stream" "firehose_cloudfront_waf_logs" {
  provider = aws.cloudfront # Firehose for CloudFront WAF logs must be in us-east-1

  # Create Firehose only if CloudFront WAF is enabled and the main CloudFront distribution is enabled.
  # This ensures the logging infrastructure is spun up only when needed.
  count = var.enable_cloudfront_waf && var.enable_cloudfront_firehose && local.enable_cloudfront_media_distribution && var.logging_bucket_enabled ? 1 : 0

  name        = "aws-waf-logs-${var.name_prefix}-cloudfront-firehose-${var.environment}"
  destination = "extended_s3" # The destination type for the logs will be extended_s3

  # --- Extended S3 Configuration for log delivery --- #
  # This block defines the specifics of how Firehose delivers logs to your S3 bucket.
  # ALL related configurations (buffering, CloudWatch logs for S3 destination)
  # must be defined WITHIN this block, as per the documentation's 's3_configuration' structure.
  extended_s3_configuration {
    role_arn            = aws_iam_role.cloudfront_firehose_role[0].arn     # IAM role granting Firehose permissions to S3 and KMS
    bucket_arn          = var.logging_bucket_arn                           # ARN of your centralized S3 logging bucket
    prefix              = "cloudfront-waf-logs/${var.environment}/"        # S3 prefix for WAF logs
    error_output_prefix = "cloudfront-waf-logs-errors/${var.environment}/" # S3 prefix for delivery errors

    # Configure data compression for cost efficiency and faster analysis
    compression_format = "GZIP"

    # --- Buffering Hints (Time and Size) for S3 destination --- #
    # These are direct arguments/fields within extended_s3_configuration (inherited from s3_configuration).
    buffering_interval = 300 # Buffer for 5 minutes (in seconds)
    buffering_size     = 5   # Buffer up to 5 MB (in MBs)

    # Configure optional KMS encryption for logs in S3.
    # Only enabled if a KMS key ARN is provided in variables.
    kms_key_arn = var.kms_key_arn != null && var.kms_key_arn != "" ? var.kms_key_arn : null

    # --- CloudWatch Logs configuration for monitoring Firehose delivery status and errors (for S3 destination) --- #
    # This block is nested within extended_s3_configuration, as per the documentation's 's3_configuration' structure.
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.name_prefix}-cloudfront-waf-logs-firehose-${var.environment}"
      log_stream_name = "delivery"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-waf-logs-firehose-${var.environment}"
  })
}

# --- Notes --- #
# 1. This Kinesis Firehose Delivery Stream is specifically configured for AWS WAF logs associated with CloudFront.
#    AWS WAF requires a Firehose stream for log delivery.
# 2. The stream is created only if 'var.enable_cloudfront_waf' is true AND 'local.enable_cloudfront_media_distribution' is true,
#    ensuring resources are only deployed when both WAF and the CloudFront distribution are active.
# 3. It delivers logs to the centralized S3 logging bucket (specified by 'var.logging_bucket_arn')
#    under the prefix 'cloudfront-waf-logs/'.
# 4. GZIP compression is enabled to reduce storage costs and improve data transfer efficiency.
# 5. Optional KMS encryption is supported if 'var.kms_key_arn' is provided, enhancing data security at rest in S3.
# 6. CloudWatch logging for Firehose itself is enabled to monitor the delivery stream's health and troubleshoot any issues.
# 7. The IAM role ('aws_iam_role.cloudfront_firehose_role') grants Firehose the necessary permissions to write to S3 and
#    use the specified KMS key (if applicable), and send logs to CloudWatch Logs. This role is defined in 'iam.tf'.
