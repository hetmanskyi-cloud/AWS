# --- CloudFront Module Outputs --- #
# This file defines the outputs exposed by the CloudFront module.
# These values can be consumed by other Terraform modules,
# or retrieved after deployment for configuration, monitoring, or integration purposes.

# --- CloudFront Distribution Outputs --- #
output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution for WordPress media."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_distribution.wordpress_media[0].id : null
  # Condition: Output only if the distribution is enabled.
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution for WordPress media."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_distribution.wordpress_media[0].arn : null
  # Condition: Output only if the distribution is enabled.
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution (e.g., d111111abcdef8.cloudfront.net)."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_distribution.wordpress_media[0].domain_name : null
  # Condition: Output only if the distribution is enabled.
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 Hosted Zone ID for use with ALIAS records (e.g., Z2FDRSLS7J2K1O)."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_distribution.wordpress_media[0].hosted_zone_id : null
  # Condition: Output only if the distribution is enabled.
}

# --- Origin Access Control (OAC) Outputs --- #
output "cloudfront_oac_id" {
  description = "The ID of the Origin Access Control (OAC) for the WordPress media S3 bucket."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_origin_access_control.wordpress_media_oac[0].id : null
  # Condition: Output only if the distribution is enabled.
}

# --- AWS WAF Web ACL Outputs --- #
output "waf_web_acl_id" {
  description = "The ID of the AWS WAFv2 Web ACL associated with the CloudFront distribution."
  value       = var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution ? aws_wafv2_web_acl.cloudfront_waf[0].id : null
  # Condition: Output only if WAF and the distribution are enabled.
}

output "waf_web_acl_arn" {
  description = "The ARN of the AWS WAFv2 Web ACL associated with the CloudFront distribution."
  value       = var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null
  # Condition: Output only if WAF and the distribution are enabled.
}

# --- Kinesis Firehose (for WAF Logs) Outputs --- #
output "firehose_delivery_stream_name" {
  description = "The name of the Kinesis Firehose Delivery Stream for CloudFront WAF logs."
  value       = var.enable_cloudfront_firehose && var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_kinesis_firehose_delivery_stream.firehose_cloudfront_waf_logs[0].name : null
  # Condition: Output only if Firehose, WAF, the distribution, and a logging bucket are enabled.
}

output "firehose_delivery_stream_arn" {
  description = "The ARN of the Kinesis Firehose Delivery Stream for CloudFront WAF logs."
  value       = var.enable_cloudfront_firehose && var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_kinesis_firehose_delivery_stream.firehose_cloudfront_waf_logs[0].arn : null
  # Condition: Output only if Firehose, WAF, the distribution, and a logging bucket are enabled.
}

# --- IAM Role for Firehose Outputs --- #
output "firehose_iam_role_arn" {
  description = "The ARN of the IAM role created for Kinesis Firehose to deliver CloudFront WAF logs."
  value       = var.enable_cloudfront_firehose && var.logging_bucket_arn != null ? aws_iam_role.cloudfront_firehose_role[0].arn : null
  # Condition: Output only if Firehose is enabled and a logging bucket is provided.
}

# --- CloudWatch Log Delivery Source Outputs --- #
output "cloudfront_access_logs_source_name" {
  description = "The name of the CloudWatch Log Delivery Source for CloudFront access logs."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_cloudwatch_log_delivery_source.cloudfront_access_logs_source[0].name : null
  # Condition: Output only if access logging v2, the distribution, and a logging bucket are enabled.
}

# --- CloudWatch Log Delivery Destination Outputs --- #
output "cloudfront_access_logs_destination_name" {
  description = "The name of the CloudWatch Log Delivery Destination (S3 bucket) for CloudFront access logs."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_cloudwatch_log_delivery_destination.cloudfront_access_logs_s3_destination[0].name : null
  # Condition: Output only if access logging v2, the distribution, and a logging bucket are enabled.
}

output "cloudfront_access_logs_destination_arn" {
  description = "The ARN of the CloudWatch Log Delivery Destination (S3 bucket) for CloudFront access logs."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_cloudwatch_log_delivery_destination.cloudfront_access_logs_s3_destination[0].arn : null
  # Condition: Output only if access logging v2, the distribution, and a logging bucket are enabled.
}

# --- CloudWatch Log Delivery Outputs --- #
output "cloudfront_access_logs_delivery_id" {
  description = "The ID of the CloudWatch Log Delivery connection for CloudFront access logs."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_cloudwatch_log_delivery.cloudfront_access_logs_delivery[0].id : null
  # Condition: Output only if access logging v2, the distribution, and a logging bucket are enabled.
}

output "cloudfront_access_logs_delivery_arn" {
  description = "The ARN of the CloudWatch Log Delivery connection for CloudFront access logs."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_arn != null ? aws_cloudwatch_log_delivery.cloudfront_access_logs_delivery[0].arn : null
  # Condition: Output only if access logging v2, the distribution, and a logging bucket are enabled.
}

# --- Output: CloudFront Standard Logging v2 S3 Log Path --- #
# This output variable provides the full S3 URI prefix for CloudFront Standard Logging v2 access logs,
# generated in Parquet format by CloudWatch Log Delivery. Use this for analytics, Athena, or integrations.
# Example: s3://wordpress-logging-gvbsn/AWSLogs/123456789012/CloudFront/cloudfront-access-logs/E2QFTKZ57D5PGR/

output "cloudfront_standard_logging_v2_log_prefix" {
  description = "The base S3 URI prefix where CloudFront Standard Logging v2 Parquet logs are delivered by CloudWatch Log Delivery."
  value       = var.enable_cloudfront_standard_logging_v2 && local.enable_cloudfront_media_distribution && var.logging_bucket_name != null ? "s3://${var.logging_bucket_name}/cloudfront-access-logs/${aws_cloudfront_distribution.wordpress_media[0].id}/" : null
}

# --- Output: CloudFront Distribution ETag --- #
output "cloudfront_distribution_etag" {
  description = "The current ETag of the CloudFront distribution, used for triggering updates in other resources."
  value       = local.enable_cloudfront_media_distribution ? aws_cloudfront_distribution.wordpress_media[0].etag : null
}

# --- WAF IP Set Outputs for VPN Integration --- #
output "waf_vpn_ip_set_id" {
  description = "The ID of the IP Set used for whitelisting VPN access."
  value       = var.enable_cloudfront_waf ? aws_wafv2_ip_set.vpn_access_ips[0].id : null
}

output "waf_vpn_ip_set_name" {
  description = "The name of the IP Set used for whitelisting VPN access."
  value       = var.enable_cloudfront_waf ? aws_wafv2_ip_set.vpn_access_ips[0].name : null
}

output "waf_vpn_ip_set_arn" {
  description = "The ARN of the IP Set used for whitelisting VPN access."
  value       = var.enable_cloudfront_waf ? aws_wafv2_ip_set.vpn_access_ips[0].arn : null
}
