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

# Flow Logs Outputs
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
  value       = module.asg.asg_id
}

output "launch_template_latest_version" {
  description = "The latest version of the EC2 Launch Template"
  value       = module.asg.launch_template_latest_version
}

output "launch_template_id" {
  description = "The ID of the ASG Launch Template"
  value       = module.asg.launch_template_id
}

output "instance_public_ips" {
  description = "Public IPs of instances in the Auto Scaling Group (if assigned)"
  value       = module.asg.instance_public_ips
}

output "instance_private_ips" {
  description = "Private IPs of instances in the Auto Scaling Group"
  value       = module.asg.instance_private_ips
}

output "instance_ids" {
  description = "Instance IDs of instances in the Auto Scaling Group"
  value       = module.asg.instance_ids
}

output "ec2_security_group_id" {
  description = "ID of the Security Group created for ASG instances"
  value       = module.asg.asg_security_group_id
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

output "rds_security_group_id" {
  description = "Security Group ID of the RDS instance"
  value       = module.rds.rds_security_group_id
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

# All Enabled Default Region Buckets
# Outputs a list of all enabled S3 bucket names in the default region.
output "all_enabled_buckets_names" {
  description = "List of all enabled S3 bucket names"
  value       = module.s3.all_enabled_buckets_names
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

output "wordpress_tg_arn" {
  description = "Target Group ARN for WordPress Auto Scaling Group"
  value       = module.alb.wordpress_tg_arn
}

# --- Secrets Manager Outputs --- #

# Output the Name of the WordPress secrets
output "wordpress_secrets_name" {
  description = "The name of the WordPress secret for ASG consumption"
  value       = aws_secretsmanager_secret.wp_secrets.name
}

# Output the ARN of the WordPress secrets
output "wordpress_secrets_arn" {
  description = "The ARN of the WordPress Secrets Manager secret"
  value       = aws_secretsmanager_secret.wp_secrets.arn
}

# --- CloudTrail Output --- #

# Outputs the ARN of the CloudTrail if enabled
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_cloudtrail.cloudtrail[0].arn : null
}

# --- Notes --- #
# - Outputs are designed for modular reuse and visibility in the Terraform state.
# - Sensitive outputs (like user_data) are marked as sensitive.
# - Ensure CloudTrail output is used conditionally based on the project configuration.