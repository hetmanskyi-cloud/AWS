# --- S3 Bucket Outputs --- #
# Defines outputs for key S3 resources.

# --- Scripts Bucket --- #

output "scripts_bucket_arn" {
  description = "ARN of scripts bucket." # Description: ARN
  value       = var.default_region_buckets["scripts"].enabled ? aws_s3_bucket.default_region_buckets["scripts"].arn : null
}

output "scripts_bucket_name" {
  description = "Name of scripts bucket." # Description: Name
  value       = var.default_region_buckets["scripts"].enabled ? aws_s3_bucket.default_region_buckets["scripts"].bucket : null
}

# --- Logging Bucket --- #

output "logging_bucket_arn" {
  description = "ARN of logging bucket." # Description: ARN
  value       = var.default_region_buckets["logging"].enabled ? aws_s3_bucket.default_region_buckets["logging"].arn : null
}

output "logging_bucket_name" {
  description = "Name of logging bucket." # Description: Name
  value       = var.default_region_buckets["logging"].enabled ? aws_s3_bucket.default_region_buckets["logging"].bucket : null
}

output "logging_bucket_id" {
  description = "ID of logging bucket." # Description: ID
  value       = var.default_region_buckets["logging"].enabled ? aws_s3_bucket.default_region_buckets["logging"].id : null
}

# --- ALB Logs Bucket --- #

# --- Output: ALB Logs Bucket Name --- #
output "alb_logs_bucket_name" {
  description = "Name of the S3 bucket for ALB logs"
  value = lookup(var.default_region_buckets, "alb_logs", {
    enabled               = false
    versioning            = false
    replication           = false
    logging               = false
    server_access_logging = false
    region                = null
  }).enabled ? aws_s3_bucket.default_region_buckets["alb_logs"].bucket : null
}

# --- AMI Bucket --- #

output "ami_bucket_arn" {
  description = "ARN of AMI bucket." # Description: ARN
  value       = var.default_region_buckets["ami"].enabled ? aws_s3_bucket.default_region_buckets["ami"].arn : null
}

output "ami_bucket_name" {
  description = "Name of AMI bucket." # Description: Name
  value       = var.default_region_buckets["ami"].enabled ? aws_s3_bucket.default_region_buckets["ami"].bucket : null
}

# --- Terraform State Bucket --- #

output "terraform_state_bucket_arn" {
  description = "ARN of Terraform state bucket." # Description: ARN
  value       = var.default_region_buckets["terraform_state"].enabled ? aws_s3_bucket.default_region_buckets["terraform_state"].arn : null
}

output "terraform_state_bucket_name" {
  description = "Name of Terraform state bucket." # Description: Name
  value       = var.default_region_buckets["terraform_state"].enabled ? aws_s3_bucket.default_region_buckets["terraform_state"].bucket : null
}

# --- WordPress Media Bucket --- #

output "wordpress_media_bucket_arn" {
  description = "ARN of WordPress media bucket." # Description: ARN
  value       = var.default_region_buckets["wordpress_media"].enabled ? aws_s3_bucket.default_region_buckets["wordpress_media"].arn : null
}

output "wordpress_media_bucket_name" {
  description = "Name of WordPress media bucket." # Description: Name
  value       = var.default_region_buckets["wordpress_media"].enabled ? aws_s3_bucket.default_region_buckets["wordpress_media"].bucket : null
}

# --- WordPress Scripts ETags Map --- #
# S3 ETags for deployed WordPress script files.
output "deploy_wordpress_scripts_files_etags_map" {
  value       = var.default_region_buckets["scripts"].enabled && var.enable_s3_script ? { for k, obj in aws_s3_object.deploy_wordpress_scripts_files : k => obj.etag } : {}
  description = "Map of script file keys to ETags." # Description: ETags map
}

# --- Replication Bucket --- #
# Since we only have one replication bucket (key "wordpress_media"), we reference it explicitly.

output "replication_bucket_arn" {
  value       = local.replication_buckets_enabled ? aws_s3_bucket.s3_replication_bucket["wordpress_media"].arn : null
  description = "ARN of replication bucket." # Description: ARN
}

output "replication_bucket_name" {
  value       = local.replication_buckets_enabled ? aws_s3_bucket.s3_replication_bucket["wordpress_media"].bucket : null
  description = "Name of replication bucket." # Description: Name
}

output "replication_bucket_region" {
  value       = local.replication_buckets_enabled ? aws_s3_bucket.s3_replication_bucket["wordpress_media"].region : null
  description = "Region of replication bucket." # Description: Region
}

# --- DynamoDB Table Outputs --- #

output "terraform_locks_table_arn" {
  description = "ARN of DynamoDB table for Terraform state locking." # Description: ARN
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].arn : null
}

output "terraform_locks_table_name" {
  description = "Name of DynamoDB table for Terraform state locking." # Description: Name
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].name : null
}

# --- DynamoDB & Lambda Outputs --- #

output "enable_dynamodb" {
  description = "DynamoDB enabled for state locking." # Description: DynamoDB enabled
  value       = var.enable_dynamodb
}

output "enable_lambda" {
  description = "Lambda enabled for TTL automation." # Description: Lambda enabled
  value       = var.enable_lambda
}

# --- Module Notes --- #
# General notes for S3 module outputs.
#
# 1. Bucket Outputs: For all configured (if enabled), null if disabled.
# 2. WordPress Scripts: 'deploy_wordpress_scripts_files_etags_map' - ETags for uploaded scripts.
# 3. DynamoDB: Outputs for state locking table (if enabled).
# 4. Lambda: Indicates Lambda enabled for TTL automation (if enabled).