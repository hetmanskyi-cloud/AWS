# --- S3 Bucket Outputs --- #
# This file defines outputs for key resources in the S3 module, including bucket ARNs, IDs, and DynamoDB table details.

# --- Base S3 Bucket Outputs --- #

# Terraform State Bucket
output "terraform_state_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing Terraform remote state files"
  value       = aws_s3_bucket.terraform_state.arn
}

# Scripts Bucket
output "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress setup scripts"
  value       = aws_s3_bucket.scripts.arn
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

# WordPress Media Bucket
# Created only in `stage` and `prod` environments.
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = var.environment == "stage" || var.environment == "prod" ? aws_s3_bucket.wordpress_media[0].arn : null
}

# --- Replication Bucket Outputs (if enabled) --- #
# Outputs for the replication bucket, which is created only in `stage` and `prod`
# environments when `enable_s3_replication` is set to true.

# Output the ARN of the replication bucket
output "replication_bucket_arn" {
  description = "The ARN of the S3 bucket used for replication destination (stage and prod only, if enabled)"
  value       = var.enable_s3_replication ? aws_s3_bucket.replication[0].arn : null
}

# Output the ID of the replication bucket
output "replication_bucket_id" {
  description = "The ID of the S3 bucket used for replication destination (stage and prod only, if enabled)"
  value       = var.enable_s3_replication ? aws_s3_bucket.replication[0].id : null
}

# --- Aggregated Bucket Outputs --- #
# Dynamically generates outputs for all buckets defined in the `buckets` variable.
# Includes:
# - List of all bucket ARNs.
# - Mapping of bucket names to their ARNs and IDs for integration.
# Only outputs buckets created in the current environment.
# Buckets that are not created in the current environment will have `null` values, ignored by Terraform.
output "all_bucket_arns" {
  description = "A list of ARNs for all S3 buckets in the module"
  value = [
    aws_s3_bucket.terraform_state.arn,                                                                     # Terraform state bucket ARN
    var.environment == "stage" || var.environment == "prod" ? aws_s3_bucket.wordpress_media[0].arn : null, # WordPress media bucket ARN
    aws_s3_bucket.scripts.arn,                                                                             # Scripts bucket ARN
    aws_s3_bucket.logging.arn,                                                                             # Logging bucket ARN
    aws_s3_bucket.ami.arn                                                                                  # AMI bucket ARN
  ]
}

# Map of bucket names to ARNs and IDs for easier integration
# This output is useful for integration with other modules or automation scripts.
# WordPress Media bucket will be null in `dev` environment.
output "bucket_details" {
  description = "A map of bucket names to their ARNs and IDs"
  value = {
    terraform_state = { arn = aws_s3_bucket.terraform_state.arn, id = aws_s3_bucket.terraform_state.id },
    wordpress_media = var.environment == "stage" || var.environment == "prod" ? { arn = aws_s3_bucket.wordpress_media[0].arn, id = aws_s3_bucket.wordpress_media[0].id } : null,
    scripts         = { arn = aws_s3_bucket.scripts.arn, id = aws_s3_bucket.scripts.id },
    logging         = { arn = aws_s3_bucket.logging.arn, id = aws_s3_bucket.logging.id },
    ami             = { arn = aws_s3_bucket.ami.arn, id = aws_s3_bucket.ami.id }
  }
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