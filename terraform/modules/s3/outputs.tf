# --- S3 Bucket Outputs --- #
# This file defines outputs for key resources in the S3 module, including bucket ARNs, IDs, and DynamoDB table details.

# --- Individual Bucket Outputs --- #

# Terraform State Bucket
output "terraform_state_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing Terraform remote state files"
  value       = aws_s3_bucket.terraform_state.arn
}

# WordPress Media Bucket
output "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket used for WordPress media storage"
  value       = var.environment == "prod" ? aws_s3_bucket.wordpress_media[0].arn : null
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

# Outputs for the "ami" bucket to provide its ID for other modules
output "ami_bucket_id" {
  description = "The ID of the S3 bucket used for storing golden AMI images"
  value       = aws_s3_bucket.ami.id
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

# --- Aggregated Outputs --- #

# Output a list of all bucket ARNs
output "all_bucket_arns" {
  description = "A list of ARNs for all S3 buckets in the module"
  value = [
    aws_s3_bucket.terraform_state.arn,                                       # Terraform state bucket ARN
    var.environment == "prod" ? aws_s3_bucket.wordpress_media[0].arn : null, # WordPress media bucket ARN (условие для prod)
    aws_s3_bucket.scripts.arn,                                               # Scripts bucket ARN
    aws_s3_bucket.logging.arn,                                               # Logging bucket ARN
    aws_s3_bucket.ami.arn                                                    # AMI bucket ARN
  ]
}

output "bucket_details" {
  description = "A map of bucket names to their ARNs and IDs"
  value = {
    terraform_state = { arn = aws_s3_bucket.terraform_state.arn, id = aws_s3_bucket.terraform_state.id },
    wordpress_media = var.environment == "prod" ? { arn = aws_s3_bucket.wordpress_media[0].arn, id = aws_s3_bucket.wordpress_media[0].id } : null,
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