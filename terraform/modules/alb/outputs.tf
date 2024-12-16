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

# --- Security Group Details --- #
# General-purpose Security Group ID
output "alb_security_group_id" {
  description = "Security Group ID of the Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

# Duplicate output for compatibility or specific use cases
output "alb_sg_id" {
  description = "Security Group ID for the Application Load Balancer"
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
output "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = var.logging_bucket
}

# Prefix for organizing ALB access logs
output "alb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs"
  value       = "${var.name_prefix}/alb-logs/"
}

# --- WAF Details --- #
# ARN of the WAF Web ACL
output "waf_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = var.environment != "dev" ? aws_wafv2_web_acl.alb_waf[0].arn : null
}

# --- Notes --- #
# 1. These outputs help other modules (e.g., EC2) to integrate with ALB.
# 2. Access Logs outputs provide flexibility for further log analysis or processing.
# 3. Duplicate security group outputs ensure compatibility where specific names are required.