# --- S3 Module Outputs --- #
# Defines outputs for key S3 resources.

# --- Scripts Bucket --- #
# IMPORTANT: The 'scripts' bucket must always be enabled in terraform.tfvars.
# This bucket stores all WordPress-related installation scripts and templates required for EC2 provisioning.

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

# --- CloudTrail Bucket --- #

output "cloudtrail_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_s3_bucket.default_region_buckets["cloudtrail"].arn : null
}

output "cloudtrail_bucket_id" {
  description = "ID of the CloudTrail S3 bucket"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_s3_bucket.default_region_buckets["cloudtrail"].id : null
}

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = var.default_region_buckets["cloudtrail"].enabled ? aws_s3_bucket.default_region_buckets["cloudtrail"].bucket : null
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

output "wordpress_media_bucket_regional_domain_name" {
  description = "The regional domain name of the WordPress media S3 bucket."  
  value       = var.default_region_buckets["wordpress_media"].enabled ? aws_s3_bucket.default_region_buckets["wordpress_media"].bucket_regional_domain_name : null
}

# --- WordPress Scripts ETags Map --- #
# S3 ETags for deployed WordPress script files.
# IMPORTANT: Scripts must be uploaded to the 'scripts' bucket. If the bucket is not enabled, the map will be empty and EC2 provisioning will fail.
output "deploy_wordpress_scripts_files_etags_map" {
  value       = var.default_region_buckets["scripts"].enabled ? { for k, obj in aws_s3_object.deploy_wordpress_scripts_files : k => obj.etag } : {}
  description = "Map of script file keys to ETags."
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

# --- DynamoDB Outputs --- #

output "enable_dynamodb" {
  description = "DynamoDB enabled for state locking." # Description: DynamoDB enabled
  value       = var.enable_dynamodb
}

# --- All Enabled Default Region Buckets --- #
# Outputs a list of all enabled S3 bucket names in the default region.
output "all_enabled_buckets_names" {
  description = "List of all enabled S3 bucket names"
  value       = [for k, b in aws_s3_bucket.default_region_buckets : b.bucket]
}

# --- Notes --- #
# 1. Bucket Outputs: For all configured (if enabled), null if disabled.
# 2. WordPress Scripts: 'deploy_wordpress_scripts_files_etags_map' - ETags for uploaded scripts.
# 3. DynamoDB: Outputs for state locking table (if enabled).