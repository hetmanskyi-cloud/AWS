# --- AWS CloudFront Access Logging v2 via CloudWatch Log Delivery (us-east-1) --- #
# This file configures CloudFront Access Logging v2 using AWS CloudWatch Log Delivery.
# This is the recommended modern approach by AWS for CloudFront logging, offering
# enhanced flexibility for log destinations (e.g., S3), output formats (e.g., Parquet),
# and improved manageability compared to legacy direct S3 logging.
# All CloudFront log delivery components, like CloudFront distributions themselves,
# must be provisioned in the us-east-1 region.

# --- CloudWatch Log Delivery Source for CloudFront Distribution --- #
# This resource defines the source of the logs, which is our CloudFront distribution.
# It establishes the connection point for CloudWatch Log Delivery to pull access logs
# from the specified CloudFront distribution.
resource "aws_cloudwatch_log_delivery_source" "cloudfront_access_logs_source" {
  provider = aws.cloudfront # Must be in us-east-1 for CloudFront resources

  # Create the log delivery source only if CloudFront access logging is enabled
  # and the main CloudFront distribution is also enabled.
  count = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution ? 1 : 0

  name         = "${var.name_prefix}-cloudfront-access-logs-source-${var.environment}"
  log_type     = "ACCESS_LOGS"                                      # Specifies that this source collects CloudFront access logs
  resource_arn = aws_cloudfront_distribution.wordpress_media[0].arn # References the ARN of our CloudFront distribution

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-access-logs-source-${var.environment}"
  })
}

# --- CloudWatch Log Delivery Destination (S3 Bucket) --- #
# This resource defines the destination where the CloudFront access logs will be delivered.
# Using Parquet format is highly recommended for cost-efficiency and optimized querying with services like AWS Athena.
resource "aws_cloudwatch_log_delivery_destination" "cloudfront_access_logs_s3_destination" {
  provider = aws.cloudfront # Must be in us-east-1

  # Create the log delivery destination only if CloudFront access logging is enabled
  # and the main CloudFront distribution is also enabled.
  count = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution ? 1 : 0

  name          = "${var.name_prefix}-cloudfront-access-logs-s3-destination-${var.environment}"
  output_format = "parquet" # Recommended format for analytics and cost reduction

  # The destination resource ARN is the S3 bucket where logs will be stored.
  delivery_destination_configuration {
    destination_resource_arn = var.logging_bucket_arn # ARN of your centralized S3 logging bucket.
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-access-logs-s3-destination-${var.environment}"
  })
}

# --- CloudWatch Log Delivery (Connecting Source to Destination) --- #
# This is the core resource that establishes the actual delivery pipeline, connecting
# the defined CloudFront log source to the S3 log destination.
# It also specifies the S3 path formatting for the delivered log files.
resource "aws_cloudwatch_log_delivery" "cloudfront_access_logs_delivery" {
  provider = aws.cloudfront # Must be in us-east-1

  # Create the log delivery only if CloudFront access logging is enabled
  # and the main CloudFront distribution is also enabled.
  count = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution ? 1 : 0

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront_access_logs_source[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront_access_logs_s3_destination[0].arn

  # The S3 bucket itself is defined by `delivery_destination_arn`.
  s3_delivery_configuration {
    # This string allows re-configuring the S3 object prefix to contain either static or variable sections.
    # The valid variables to use in the suffix path will vary by each log source.
    # For CloudFront, common variables include {DistributionId}, {yyyy}, {MM}, {dd}, {HH}.
    # Includes a static prefix and dynamic components here.
    suffix_path = "cloudfront-access-logs/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}/" # Combined static prefix and dynamic path
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-access-logs-delivery-${var.environment}"
  })
}

# --- Notes --- #
# 1. This file orchestrates CloudFront Access Logging v2 using AWS CloudWatch Log Delivery.
#    This is the modern and recommended method for robust CloudFront logging.
# 2. All resources related to CloudFront Log Delivery (source, destination, and delivery itself)
#    must be provisioned in the 'us-east-1' region, using the 'aws.cloudfront' provider alias.
#    This aligns with the global nature of CloudFront services.
# 3. Three distinct resources are created:
#    - `aws_cloudwatch_log_delivery_source`: Identifies the CloudFront distribution as the origin of logs.
#    - `aws_cloudwatch_log_delivery_destination`: Specifies the centralized S3 logging bucket as the target.
#      Logs are configured to be delivered in 'parquet' format for efficiency and analytics.
#      The `destination_resource_arn` for S3 is simply the bucket's ARN, but ONLY inside
#      `delivery_destination_configuration` block.
#    - `aws_cloudwatch_log_delivery`: Connects the source and destination, defining the exact S3 path structure
#      for log files within the destination bucket. The `s3_delivery_configuration` block uses `suffix_path`
#      to build the full S3 path, incorporating both a static prefix and dynamic elements like
#      {DistributionId}, year, month, day, and hour.
# 4. Critical requirement: The S3 bucket specified by `var.logging_bucket_arn` must have a bucket policy
#    that grants `delivery.logs.amazonaws.com` (the CloudWatch Log Delivery service principal)
#    permissions to put objects (`s3:PutObject`) and get bucket ACL (`s3:GetBucketAcl`).
#    A typical policy statement for this would look like:
#    ```json
#    {
#        "Effect": "Allow",
#        "Principal": {
#            "Service": "delivery.logs.amazonaws.com"
#        },
#        "Action": [
#            "s3:PutObject",
#            "s3:GetBucketAcl"
#        ],
#        "Resource": [
#            "arn:aws:s3:::YOUR_LOG_BUCKET_NAME",
#            "arn:aws:s3:::YOUR_LOG_BUCKET_NAME/cloudfront-access-logs/*"
#        ]
#    }
#    ```
#    Ensure this policy is attached to your S3 logging bucket.
# 5. Resources are conditionally created based on `var.enable_cloudfront_standard_logging_v2g`
#    and `local.enable_cloudfront_media_distribution`, ensuring deployment only when logging
#    and the associated CloudFront distribution are enabled.
# 6. Consistent tagging (`var.tags`) is applied for resource identification and cost allocation.