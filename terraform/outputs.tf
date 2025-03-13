# --- VPC Module Outputs --- #
output "vpc_id" {
  description = "The ID of the VPC created in the VPC module"
  value       = module.vpc.vpc_id
}

output "public_subnet_1_id" {
  description = "ID of the first public subnet"
  value       = module.vpc.public_subnet_1_id
}

output "public_subnet_2_id" {
  description = "ID of the second public subnet"
  value       = module.vpc.public_subnet_2_id
}

output "public_subnet_3_id" {
  description = "ID of the third public subnet"
  value       = module.vpc.public_subnet_3_id
}

output "private_subnet_1_id" {
  description = "ID of the first private subnet"
  value       = module.vpc.private_subnet_1_id
}

output "private_subnet_2_id" {
  description = "ID of the second private subnet"
  value       = module.vpc.private_subnet_2_id
}

output "private_subnet_3_id" {
  description = "ID of the third private subnet"
  value       = module.vpc.private_subnet_3_id
}

# --- Flow Logs Outputs --- #
output "vpc_flow_logs_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = module.vpc.vpc_flow_logs_log_group_name
}

output "vpc_flow_logs_role_arn" {
  description = "IAM Role ARN for VPC Flow Logs"
  value       = module.vpc.vpc_flow_logs_role_arn
}

# --- KMS Module Outputs --- #
output "kms_key_arn" {
  description = "KMS key ARN created for encrypting resources"
  value       = module.kms.kms_key_arn
}

# --- ASG Module Outputs --- #
output "asg_id" {
  description = "The ID of the Auto Scaling Group"
  value       = try(module.asg[0].asg_id, null)
}

output "launch_template_latest_version" {
  description = "The latest version of the EC2 Launch Template"
  value       = try(module.asg[0].launch_template_latest_version, null)
}

output "launch_template_id" {
  description = "The ID of the ASG Launch Template"
  value       = try(module.asg[0].launch_template_id, null)
}

output "instance_public_ips" {
  description = "Public IPs of instances in the Auto Scaling Group (if assigned)"
  value       = try(module.asg[0].instance_public_ips, null)
}

output "instance_private_ips" {
  description = "Private IPs of instances in the Auto Scaling Group"
  value       = try(module.asg[0].instance_private_ips, null)
}

output "instance_ids" {
  description = "Instance IDs of instances in the Auto Scaling Group"
  value       = try(module.asg[0].instance_ids, null)
}

output "ec2_security_group_id" {
  description = "ID of the Security Group created for ASG instances"
  value       = try(module.asg[0].asg_security_group_id, null)
}

output "rendered_user_data" {
  value       = module.asg.rendered_user_data
  description = "Rendered user_data script passed to EC2 instances."
  sensitive   = true
}

# --- RDS Module Outputs --- #
output "db_host" {
  description = "The hostname of the RDS instance"
  value       = module.rds.db_host
}

output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "The port of the RDS instance"
  value       = module.rds.db_port
}

# --- S3 Module Outputs --- #

# Output the ARN of the WordPress media bucket
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = module.s3.wordpress_media_bucket_arn
}

# Output the ARN of the WordPress scripts bucket
output "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress setup scripts"
  value       = module.s3.scripts_bucket_arn
}

# --- SNS Topic Outputs --- #

output "sns_topic_arn" {
  value       = aws_sns_topic.cloudwatch_alarms.arn
  description = "ARN of the SNS topic"
}

# --- Elasticache Module Outputs --- #

# Output Redis endpoint from the elasticache module
output "redis_endpoint" {
  description = "The primary endpoint of the Redis replication group"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "The port of the Redis replication group"
  value       = module.elasticache.redis_port
}

# --- ALB Module Outputs --- #
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_security_group_id" {
  description = "The security group ID of the ALB"
  value       = module.alb.alb_security_group_id
}

# --- Secrets Manager Outputs --- #

# Output the ARN of the WordPress secrets
output "secret_arn" {
  description = "ARN of the WordPress secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.wp_secrets.arn
}

# Output the name of the secret
output "secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.wp_secrets.name
}