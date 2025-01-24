# --- S3 Bucket Outputs --- #
# Defines outputs for key S3 resources, including ARNs, IDs, and bucket names.

# Scripts Bucket
output "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress setup scripts"
  value       = lookup(var.buckets, "scripts", false) ? aws_s3_bucket.buckets["scripts"].arn : null
}

# Output the Scripts bucket name
output "scripts_bucket_name" {
  description = "The name of the S3 bucket for deployment scripts"
  value       = length(aws_s3_bucket.scripts) > 0 ? aws_s3_bucket.scripts[0].bucket : null
}

# Logging Bucket
output "logging_bucket_arn" {
  description = "The ARN of the S3 bucket used for logging"
  value       = length(aws_s3_bucket.logging) > 0 ? aws_s3_bucket.logging[0].arn : null
}

output "deploy_wordpress_script_etag" {
  value       = length(aws_s3_object.deploy_wordpress_script) > 0 ? aws_s3_object.deploy_wordpress_script[0].etag : null
  description = "The ETag of the Deploy WordPress Script object in S3."
}

# Output the ID of the logging bucket
output "logging_bucket_id" {
  description = "The ID of the S3 bucket used for logging"
  value       = length(aws_s3_bucket.logging) > 0 ? aws_s3_bucket.logging[0].id : null
}

# AMI Bucket
output "ami_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing golden AMI images"
  value       = length(aws_s3_bucket.ami) > 0 ? aws_s3_bucket.ami[0].arn : null
}

# Outputs for the AMI bucket to provide its ID for other modules
output "ami_bucket_id" {
  description = "The ID of the S3 bucket used for storing golden AMI images"
  value       = length(aws_s3_bucket.ami) > 0 ? aws_s3_bucket.ami[0].id : null
}

# Output the AMI S3 bucket name
output "ami_bucket_name" {
  description = "The name of the S3 bucket for storing AMI images"
  value       = length(aws_s3_bucket.ami) > 0 ? aws_s3_bucket.ami[0].bucket : null
}

# Terraform State Bucket
output "terraform_state_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing Terraform remote state files"
  value       = var.buckets["terraform_state"] ? aws_s3_bucket.terraform_state[0].arn : null
}

# WordPress Media Bucket
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = var.buckets["wordpress_media"] ? aws_s3_bucket.wordpress_media[0].arn : null
}

# Output the ID of the WordPress media bucket
output "wordpress_media_bucket_id" {
  description = "The ID of the S3 bucket used for WordPress media storage"
  value       = var.buckets["wordpress_media"] ? aws_s3_bucket.wordpress_media[0].id : null
}

# Output the WordPress media bucket name
output "wordpress_media_bucket_name" {
  description = "The name of the S3 bucket for WordPress media storage"
  value       = var.buckets["wordpress_media"] ? aws_s3_bucket.wordpress_media[0].bucket : null
}

# --- Replication Bucket Outputs --- #

# Output the ARN of the replication bucket
output "replication_bucket_arn" {
  description = "The ARN of the replication S3 bucket if enabled"
  value       = lookup(var.buckets, "replication", false) && var.enable_s3_replication ? (contains(keys(aws_s3_bucket.buckets), "replication") ? aws_s3_bucket.buckets["replication"].arn : null) : null
}

# Output the ID of the replication bucket
output "replication_bucket_id" {
  description = "The ID of the replication S3 bucket if enabled"
  value       = lookup(var.buckets, "replication", false) && var.enable_s3_replication ? (contains(keys(aws_s3_bucket.buckets), "replication") ? aws_s3_bucket.buckets["replication"].id : null) : null
}

# Output the name of the replication bucket
output "replication_bucket_name" {
  description = "The name of the S3 bucket used for replication destination"
  value       = lookup(var.buckets, "replication", false) ? aws_s3_bucket.replication[0].bucket : null
}

# --- Aggregated Bucket Outputs --- #

# Dynamically generates outputs for all buckets defined in the `buckets` variable.
# List of all bucket ARNs.
output "all_bucket_arns" {
  description = "A list of ARNs for all S3 buckets in the module"
  value = compact([
    length(aws_s3_bucket.scripts) > 0 ? aws_s3_bucket.scripts[0].arn : null,
    length(aws_s3_bucket.logging) > 0 ? aws_s3_bucket.logging[0].arn : null,
    length(aws_s3_bucket.ami) > 0 ? aws_s3_bucket.ami[0].arn : null,
    lookup(var.buckets, "terraform_state", false) && length(aws_s3_bucket.terraform_state) > 0 ? aws_s3_bucket.terraform_state[0].arn : null,
    lookup(var.buckets, "wordpress_media", false) && length(aws_s3_bucket.wordpress_media) > 0 ? aws_s3_bucket.wordpress_media[0].arn : null,
    lookup(var.buckets, "replication", false) && length(aws_s3_bucket.replication) > 0 ? aws_s3_bucket.replication[0].arn : null
  ])
}

# Map of bucket names to ARNs and IDs
# This output is useful for integration with other modules or automation scripts.
output "bucket_details" {
  description = "A map of bucket names to their ARNs and IDs"
  value = {
    scripts         = length(aws_s3_bucket.scripts) > 0 ? { arn = aws_s3_bucket.scripts[0].arn, id = aws_s3_bucket.scripts[0].id } : null,
    logging         = length(aws_s3_bucket.logging) > 0 ? { arn = aws_s3_bucket.logging[0].arn, id = aws_s3_bucket.logging[0].id } : null,
    ami             = length(aws_s3_bucket.ami) > 0 ? { arn = aws_s3_bucket.ami[0].arn, id = aws_s3_bucket.ami[0].id } : null,
    terraform_state = lookup(var.buckets, "terraform_state", false) && length(aws_s3_bucket.terraform_state) > 0 ? { arn = aws_s3_bucket.terraform_state[0].arn, id = aws_s3_bucket.terraform_state[0].id } : null,
    wordpress_media = lookup(var.buckets, "wordpress_media", false) && length(aws_s3_bucket.wordpress_media) > 0 ? { arn = aws_s3_bucket.wordpress_media[0].arn, id = aws_s3_bucket.wordpress_media[0].id } : null,
    replication     = lookup(var.buckets, "replication", false) && length(aws_s3_bucket.replication) > 0 ? { arn = aws_s3_bucket.replication[0].arn, id = aws_s3_bucket.replication[0].id } : null
  }
}

# --- DynamoDB Table Outputs --- #

# DynamoDB table for Terraform state locking
output "terraform_locks_table_name" {
  description = "The name of the DynamoDB table used for Terraform state locking"
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].name : null
}

# Output the ARN of the DynamoDB table for Terraform state locking
output "terraform_locks_table_arn" {
  description = "The ARN of the DynamoDB table used for Terraform state locking"
  value       = var.enable_dynamodb ? aws_dynamodb_table.terraform_locks[0].arn : null
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

# --- Notes and Best Practices --- #
# 1. Outputs dynamically handle optional buckets:
#    - Disabled buckets return `null` for their outputs.
#
# 2. Aggregated Outputs:
#    - `all_bucket_arns` consolidates ARNs of all enabled buckets.
#    - `bucket_details` provides a map of bucket names, ARNs, and IDs for easy integration.
#
# 3. DynamoDB Outputs:
#    - Used for Terraform state locking. Ensure proper configuration of the table.
#
# 4. Customization:
#    - Adjust the `buckets` variable and enable/disable buckets as per environment needs.