# --- Metadata Outputs --- #
# Export final tag maps per component to make them available in other Terraform files.
# These outputs are used to pass dynamically generated tags into modules and resources.

output "tags_vpc" {
  description = "Tags for VPC resources"
  value       = local.tags_vpc
}

output "tags_asg" {
  description = "Tags for Auto Scaling Group resources"
  value       = local.tags_asg
}

output "tags_rds" {
  description = "Tags for RDS instance"
  value       = local.tags_rds
}

output "tags_s3" {
  description = "Tags for S3 buckets"
  value       = local.tags_s3
}

output "tags_kms" {
  description = "Tags for KMS key"
  value       = local.tags_kms
}

output "tags_alb" {
  description = "Tags for Application Load Balancer"
  value       = local.tags_alb
}

output "tags_redis" {
  description = "Tags for ElastiCache Redis"
  value       = local.tags_redis
}

output "tags_cloudtrail" {
  description = "Tags for CloudTrail logs"
  value       = local.tags_cloudtrail
}

output "tags_cloudwatch" {
  description = "Tags for CloudWatch alarms"
  value       = local.tags_cloudwatch
}

output "tags_interface_endpoints" {
  description = "Tags for VPC Interface Endpoints"
  value       = local.tags_interface_endpoints
}

output "tags_secrets" {
  description = "Tags for Secrets Manager"
  value       = local.tags_secrets
}

output "tags_sns" {
  description = "Tags for SNS topic"
  value       = local.tags_sns
}

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
  description = "Rendered EC2 user_data (base64 template) for bootstrap configuration; sensitive to avoid logging."
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

output "sns_cloudwatch_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

output "sns_cloudtrail_topic_name" {
  description = "SNS topic name used by CloudTrail"
  value       = length(aws_sns_topic.cloudtrail_events) > 0 ? aws_sns_topic.cloudtrail_events[0].name : null
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

# Provides clear access to the names and ARNs of all created secrets.
# This is a best practice for visibility, debugging, and interoperability with other Terraform states.

# --- WordPress Application Secret --- #
output "wordpress_secrets_name" {
  description = "The name of the WordPress application secret (contains keys, salts, admin credentials)."
  value       = aws_secretsmanager_secret.wp_secrets.name
}

output "wordpress_secrets_arn" {
  description = "The ARN of the WordPress application secret."
  value       = aws_secretsmanager_secret.wp_secrets.arn
}

# --- RDS Database Secret --- #
output "rds_secrets_name" {
  description = "The name of the RDS database secret."
  value       = aws_secretsmanager_secret.rds_secrets.name
}

output "rds_secrets_arn" {
  description = "The ARN of the RDS database secret."
  value       = aws_secretsmanager_secret.rds_secrets.arn
}

# --- Redis AUTH Secret --- #
output "redis_auth_secret_name" {
  description = "The name of the Redis AUTH token secret."
  value       = aws_secretsmanager_secret.redis_auth.name
}

output "redis_auth_secret_arn" {
  description = "The ARN of the Redis AUTH token secret."
  value       = aws_secretsmanager_secret.redis_auth.arn
}

# --- CloudTrail Output --- #

# Outputs the ARN of the CloudTrail if enabled
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_cloudtrail.cloudtrail[0].arn : null
}

output "cloudtrail_id" {
  description = "ID of the CloudTrail"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_cloudtrail.cloudtrail[0].id : null
}

# --- CloudWatch Log Groups Outputs --- #

output "cloudwatch_user_data_log_group_name" {
  value       = try(aws_cloudwatch_log_group.user_data_logs[0].name, null)
  description = "CloudWatch Log Group for EC2 user-data script logs"
}

output "cloudwatch_system_log_group_name" {
  value       = try(aws_cloudwatch_log_group.system_logs[0].name, null)
  description = "CloudWatch Log Group for EC2 system logs"
}

output "cloudwatch_nginx_log_group_name" {
  value       = try(aws_cloudwatch_log_group.nginx_logs[0].name, null)
  description = "CloudWatch Log Group for Nginx logs"
}

output "cloudwatch_php_fpm_log_group_name" {
  value       = try(aws_cloudwatch_log_group.php_fpm_logs[0].name, null)
  description = "CloudWatch Log Group for PHP-FPM logs"
}

output "cloudwatch_wordpress_log_group_name" {
  value       = try(aws_cloudwatch_log_group.wordpress_logs[0].name, null)
  description = "CloudWatch Log Group for WordPress debug/application logs"
}

# --- CloudFront Outputs --- #

# Output: CloudFront Standard Logging v2 S3 Log Path (from CloudFront Module)
# This output exposes the S3 URI prefix for CloudFront Standard Logging v2 access logs
# from the child 'cloudfront' module to the root level.
output "cloudfront_standard_logging_v2_log_prefix" {
  description = "S3 URI prefix for CloudFront Standard Logging v2 Parquet logs."
  value       = module.cloudfront.cloudfront_standard_logging_v2_log_prefix
}

# Output: CloudFront → ALB Custom Header Secret
output "cloudfront_to_alb_secret_header_value" {
  description = "Secret value for the custom CloudFront → ALB header"
  value       = random_password.cloudfront_to_alb_header.result
  sensitive   = true
}

# --- Notes --- #
# - Outputs are designed for modular reuse and visibility in the Terraform state.
# - Sensitive outputs (like user_data) are marked as sensitive.
# - Ensure CloudTrail output is used conditionally based on the project configuration.
