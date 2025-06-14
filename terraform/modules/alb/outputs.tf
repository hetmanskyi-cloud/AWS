# --- ALB Module Outputs --- #

# --- ALB Details --- #
# Provides the ARN of the Application Load Balancer.
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.application.arn
}

# Provides the DNS name of the Application Load Balancer.
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.application.dns_name
}

# Provides the Name of the Application Load Balancer.
output "alb_name" {
  description = "Name of the Application Load Balancer"
  value       = aws_lb.application.name
}

# General-purpose Security Group ID
# Allows other modules (e.g., ASG, VPC Endpoints) to reference the ALB Security Group for traffic rules.
output "alb_security_group_id" {
  description = "Primary Security Group ID of the Application Load Balancer for integration with other modules"
  value       = aws_security_group.alb_sg.id
}

# --- Target Group Details --- #
# WordPress Target Group ARN
output "wordpress_tg_arn" {
  description = "ARN of the Target Group for WordPress"
  value       = aws_lb_target_group.wordpress.arn
}

# --- Target Group Name --- #
# Useful for manual inspection, CloudWatch dashboards, or CLI tools.
output "alb_target_group_name" {
  description = "Name of the WordPress target group"
  value       = aws_lb_target_group.wordpress.name
}

# --- Access Logs Outputs --- #
# S3 bucket for ALB access logs
# Outputs the S3 bucket name used for ALB access logs (if access logging is enabled).
output "alb_access_logs_bucket_name" {
  description = "Name of the S3 bucket for ALB access logs"
  value       = var.alb_logs_bucket_name
}

# --- WAF Details --- #

output "alb_waf_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb_waf[0].arn : null
}

output "alb_waf_logs_firehose_arn" {
  description = "The ARN of the Kinesis Firehose delivery stream for ALB WAF logs."
  value       = var.enable_alb_firehose ? aws_kinesis_firehose_delivery_stream.firehose_alb_waf_logs[0].arn : null
}

# --- HTTPS Listener --- #
# Indicates whether the HTTPS listener is enabled on the ALB.
# Useful for conditionally configuring resources that depend on HTTPS being active.
output "enable_https_listener" {
  description = "Enable or disable HTTPS listener in ALB"
  value       = var.enable_https_listener
}

# --- Outputs for ALB CloudWatch Alarms --- #
# These outputs expose the ARNs of CloudWatch Alarms for monitoring and integration with alerting systems (e.g., SNS).

# High request count alarm
output "alb_high_request_count_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for high request count on the ALB."
  value       = length(aws_cloudwatch_metric_alarm.alb_high_request_count) > 0 ? aws_cloudwatch_metric_alarm.alb_high_request_count[0].arn : null
}

# 5XX errors alarm
output "alb_5xx_errors_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for HTTP 5XX errors on the ALB."
  value       = length(aws_cloudwatch_metric_alarm.alb_5xx_errors) > 0 ? aws_cloudwatch_metric_alarm.alb_5xx_errors[0].arn : null
}

# Target response time alarm
output "alb_target_response_time_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for target response time on the ALB."
  value       = length(aws_cloudwatch_metric_alarm.alb_target_response_time) > 0 ? aws_cloudwatch_metric_alarm.alb_target_response_time[0].arn : null
}

# Unhealthy host count alarm
output "alb_unhealthy_host_count_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for unhealthy targets in the ALB target group. This alarm is always created as it's critical for monitoring."
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_host_count.arn
}

# --- Notes --- #
# 1. These outputs help other modules (e.g., ASG) to integrate with ALB.
# 2. Access Logs outputs provide flexibility for further log analysis or processing.