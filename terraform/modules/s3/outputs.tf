# --- S3 Bucket Outputs --- #
# Defines outputs for key S3 resources.

# --- Scripts Bucket --- #

output "scripts_bucket_arn" {
  description = "ARN of the scripts bucket."
  value       = var.buckets["scripts"].enabled ? aws_s3_bucket.buckets["scripts"].arn : null
}

output "scripts_bucket_name" {
  description = "Name of the scripts bucket."
  value       = var.buckets["scripts"].enabled ? aws_s3_bucket.buckets["scripts"].bucket : null
}

# --- Logging Bucket --- #

output "logging_bucket_arn" {
  description = "ARN of the logging bucket."
  value       = var.buckets["logging"].enabled ? aws_s3_bucket.buckets["logging"].arn : null
}

output "logging_bucket_name" {
  description = "Name of the logging bucket."
  value       = var.buckets["logging"].enabled ? aws_s3_bucket.buckets["logging"].bucket : null
}

# --- AMI Bucket --- #

output "ami_bucket_arn" {
  description = "ARN of the AMI bucket."
  value       = var.buckets["ami"].enabled ? aws_s3_bucket.buckets["ami"].arn : null
}

output "ami_bucket_name" {
  description = "Name of the AMI bucket."
  value       = var.buckets["ami"].enabled ? aws_s3_bucket.buckets["ami"].bucket : null
}

# --- Terraform_state Bucket --- #

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = var.buckets["terraform_state"].enabled ? aws_s3_bucket.buckets["terraform_state"].arn : null
}

output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket."
  value       = var.buckets["terraform_state"].enabled ? aws_s3_bucket.buckets["terraform_state"].bucket : null
}

# --- WordPress_media Bucket --- #

output "wordpress_media_bucket_arn" {
  description = "ARN of the WordPress media bucket."
  value       = var.buckets["wordpress_media"].enabled ? aws_s3_bucket.buckets["wordpress_media"].arn : null
}

output "wordpress_media_bucket_name" {
  description = "Name of the WordPress media bucket."
  value       = var.buckets["wordpress_media"].enabled ? aws_s3_bucket.buckets["wordpress_media"].bucket : null
}

# Output: S3 ETags for the deployed WordPress script files.
# ETags uniquely identify an object's version in S3.
# For non-multipart uploads, an ETag is typically the MD5 hash of the file.
# This map can be used to verify file integrity and track changes.
output "deploy_wordpress_scripts_files_etags_map" {
  value       = var.buckets["scripts"].enabled && var.enable_s3_script ? { for k, obj in aws_s3_object.deploy_wordpress_scripts_files : k => obj.etag } : {}
  description = "Map of script file keys to ETags."
}

# --- Replication Bucket --- #

output "replication_bucket_arn" {
  value       = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? aws_s3_bucket.buckets["replication"].arn : null
  description = "ARN of the replication bucket."
}

output "replication_bucket_name" {
  value       = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? aws_s3_bucket.buckets["replication"].bucket : null
  description = "Name of the replication bucket."
}

# --- Encryption Status --- #

output "s3_encryption_status" {
  value = {
    for bucket_name, bucket_config in var.buckets : bucket_name =>
    bucket_config.enabled ? try(
      aws_s3_bucket_server_side_encryption_configuration.encryption[bucket_name].rule[0].apply_server_side_encryption_by_default.sse_algorithm,
      "Not Encrypted"
    ) : "Not Encrypted"
  }
  description = "Map of bucket names to their encryption status."
}

# --- DynamoDB Table Outputs --- #

output "terraform_locks_table_arn" {
  description = "The ARN of the DynamoDB table used for Terraform state locking"
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].arn : null
}

output "terraform_locks_table_name" {
  description = "The name of the DynamoDB table used for Terraform state locking"
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].name : null
}

# --- DynamoDB and Lambda Outputs --- #

output "enable_dynamodb" {
  description = "Flag indicating if DynamoDB is enabled for state locking"
  value       = var.enable_dynamodb
}

output "enable_lambda" {
  description = "Flag indicating if Lambda is enabled for TTL automation"
  value       = var.enable_lambda
}

# --- Notes --- #
# 1. Bucket Outputs:
#    - Outputs are provided for all configured buckets (if enabled).
#    - Disabled buckets return `null` for their outputs.
# 2. WordPress Scripts:
#    - 'deploy_wordpress_scripts_files_etags_map' provides ETags for uploaded scripts.
# 3. Encryption Status:
#    - 's3_encryption_status' indicates the server-side encryption status for each bucket.
# 4. DynamoDB:
#    - Outputs are provided for the DynamoDB table used for state locking (if enabled).
# 5. Lambda:
#    - Outputs indicate whether Lambda is enabled for TTL automation (if enabled).