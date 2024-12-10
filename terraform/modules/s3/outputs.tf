# --- S3 Bucket Outputs --- #
# This file defines outputs for key resources in the S3 module, including bucket ARNs, IDs, and DynamoDB table details.

# --- Terraform State Bucket Outputs --- #

# Output the ARN of the Terraform state bucket
output "terraform_state_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing Terraform remote state files"
  value       = aws_s3_bucket.terraform_state.arn
}

# --- DynamoDB Table Outputs --- #

# Output the name of the DynamoDB table for Terraform state locking
output "terraform_locks_table_name" {
  description = "The name of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

# Output the ARN of the DynamoDB table for Terraform state locking
output "terraform_locks_table_arn" {
  description = "The ARN of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

# --- WordPress Buckets Outputs --- #

# Output the ARN of the WordPress media bucket
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = aws_s3_bucket.wordpress_media.arn
}

# Output the ARN of the WordPress scripts bucket
output "wordpress_scripts_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress setup scripts"
  value       = aws_s3_bucket.wordpress_scripts.arn
}

# --- Logging Bucket Outputs --- #

# Output the ARN of the logging bucket
output "logging_bucket_arn" {
  description = "The ARN of the S3 bucket used for logging"
  value       = aws_s3_bucket.logging.arn
}

# Output the ID of the logging bucket
output "logging_bucket_id" {
  description = "The ID of the S3 bucket used for logging"
  value       = aws_s3_bucket.logging.id
}

# --- Aggregated Outputs --- #

# Output a list of all bucket ARNs
output "all_bucket_arns" {
  description = "A list of ARNs for all S3 buckets in the module"
  value = [
    aws_s3_bucket.terraform_state.arn,   # Terraform state bucket ARN
    aws_s3_bucket.wordpress_media.arn,   # WordPress media bucket ARN
    aws_s3_bucket.wordpress_scripts.arn, # WordPress scripts bucket ARN
    aws_s3_bucket.logging.arn            # Logging bucket ARN
  ]
}

# --- Replication Bucket Outputs --- #

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
