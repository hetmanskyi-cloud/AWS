# --- Outputs from the ALB Module --- #

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.application.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.application.dns_name
}

output "alb_security_group_id" {
  description = "Security Group ID of the ALB"
  value       = aws_security_group.alb_sg.id
}

output "alb_name" {
  description = "Name of the Application Load Balancer"
  value       = aws_lb.application.name
}

output "alb_sg_id" {
  description = "Security Group ID for the Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

output "wordpress_tg_arn" {
  description = "ARN of the Target Group for WordPress"
  value       = aws_lb_target_group.wordpress.arn
}
