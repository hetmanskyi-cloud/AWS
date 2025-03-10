# --- Outputs from the ALB Module --- #

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

# --- Access Logs Outputs --- #

# S3 bucket for ALB access logs
output "alb_access_logs_bucket_name" {
  description = "Name of the S3 bucket for ALB access logs"
  value       = var.alb_logs_bucket_name # <---- Исправлено: Используем правильную переменную var.alb_logs_bucket_name
}

# --- WAF Details --- #
# ARN of the WAF Web ACL
output "waf_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.alb_waf[0].arn : null
}

# --- HTTPS Listener --- #
output "enable_https_listener" {
  description = "Enable or disable HTTPS listener in ALB"
  value       = var.enable_https_listener
}

# --- Outputs for ALB CloudWatch Alarms --- #

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

# Health check failed alarm
output "alb_health_check_failed_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for ALB health check failures."
  value       = length(aws_cloudwatch_metric_alarm.alb_health_check_failed) > 0 ? aws_cloudwatch_metric_alarm.alb_health_check_failed[0].arn : null
}

# Unhealthy host count alarm
output "alb_unhealthy_host_count_alarm_arn" {
  description = "ARN of the CloudWatch Alarm for unhealthy targets in the ALB target group. This alarm is always created as it's critical for monitoring."
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_host_count.arn
}

# --- Notes --- #
# 1. These outputs help other modules (e.g., ASG) to integrate with ALB.
# 2. Access Logs outputs provide flexibility for further log analysis or processing.