# --- S3 Bucket Outputs --- #
# Defines outputs for key S3 resources, including ARNs, IDs, and bucket names.

# --- Base S3 Bucket Outputs --- #

# Scripts Bucket
output "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress setup scripts"
  value       = aws_s3_bucket.scripts.arn
}

# Output the Scripts bucket name
output "scripts_bucket_name" {
  description = "The name of the S3 bucket for deployment scripts"
  value       = aws_s3_bucket.scripts.bucket
}

# Logging Bucket
output "logging_bucket_arn" {
  description = "The ARN of the S3 bucket used for logging"
  value       = aws_s3_bucket.logging.arn
}

# Output the ID of the logging bucket
output "logging_bucket_id" {
  description = "The ID of the S3 bucket used for logging"
  value       = aws_s3_bucket.logging.id
}

# AMI Bucket
output "ami_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing golden AMI images"
  value       = aws_s3_bucket.ami.arn
}

# Outputs for the AMI bucket to provide its ID for other modules
output "ami_bucket_id" {
  description = "The ID of the S3 bucket used for storing golden AMI images"
  value       = aws_s3_bucket.ami.id
}

# Output the AMI S3 bucket name
output "ami_bucket_name" {
  description = "The name of the S3 bucket for storing AMI images"
  value       = aws_s3_bucket.ami.bucket
}

# --- Special S3 Bucket Outputs --- #

# Terraform State Bucket
output "terraform_state_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing Terraform remote state files"
  value       = var.enable_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].arn : null
}

# WordPress Media Bucket
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0].arn : null
}

# Output the ID of the WordPress media bucket
output "wordpress_media_bucket_id" {
  description = "The ID of the S3 bucket used for WordPress media storage"
  value       = var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0].id : null
}

# Output the WordPress media bucket name
output "wordpress_media_bucket_name" {
  description = "The name of the S3 bucket for WordPress media storage"
  value       = var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0].bucket : null
}

# Output the ETag of the uploaded object
output "deploy_wordpress_script_etag" {
  value       = aws_s3_object.deploy_wordpress_script.etag
  description = "The ETag of the Deploy WordPress Script object in S3."
}

# --- Replication Bucket Outputs (if enabled) --- #

# Output the ARN of the replication bucket
output "replication_bucket_arn" {
  description = "The ARN of the S3 bucket used for replication destination"
  value       = var.enable_s3_replication ? aws_s3_bucket.replication[0].arn : null
}

# Output the ID of the replication bucket
output "replication_bucket_id" {
  description = "The ID of the S3 bucket used for replication destination"
  value       = var.enable_s3_replication ? aws_s3_bucket.replication[0].id : null
}

# Output the name of the replication bucket
output "replication_bucket_name" {
  description = "The name of the S3 bucket used for replication destination"
  value       = var.enable_replication_bucket ? aws_s3_bucket.replication[0].bucket : null
}

# --- Aggregated Bucket Outputs --- #

# Dynamically generates outputs for all buckets defined in the `buckets` variable.
# List of all bucket ARNs.
output "all_bucket_arns" {
  description = "A list of ARNs for all S3 buckets in the module"
  value = compact([
    aws_s3_bucket.scripts.arn,
    aws_s3_bucket.logging.arn,
    aws_s3_bucket.ami.arn,
    var.enable_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].arn : null,
    var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0].arn : null,
    var.enable_replication_bucket ? aws_s3_bucket.replication[0].arn : null
  ])
}

# Map of bucket names to ARNs and IDs
# This output is useful for integration with other modules or automation scripts.
output "bucket_details" {
  description = "A map of bucket names to their ARNs and IDs"
  value = {
    scripts         = { arn = aws_s3_bucket.scripts.arn, id = aws_s3_bucket.scripts.id },
    logging         = { arn = aws_s3_bucket.logging.arn, id = aws_s3_bucket.logging.id },
    ami             = { arn = aws_s3_bucket.ami.arn, id = aws_s3_bucket.ami.id },
    terraform_state = var.enable_terraform_state_bucket ? { arn = aws_s3_bucket.terraform_state[0].arn, id = aws_s3_bucket.terraform_state[0].id } : null,
    wordpress_media = var.enable_wordpress_media_bucket ? { arn = aws_s3_bucket.wordpress_media[0].arn, id = aws_s3_bucket.wordpress_media[0].id } : null,
    replication     = var.enable_replication_bucket ? { arn = aws_s3_bucket.replication[0].arn, id = aws_s3_bucket.replication[0].id } : null
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