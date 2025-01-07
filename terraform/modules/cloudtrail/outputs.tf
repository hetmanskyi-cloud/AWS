output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = var.enable_logging ? aws_cloudtrail.this[0].arn : null
}
