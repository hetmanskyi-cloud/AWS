# --- S3 Module Variables --- #
# This file defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Configuration ---#
# Region where the replication bucket will be created, typically different from the primary region.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- Environment Variable --- #
# Determines the deployment environment (e.g., dev, stage, prod) and drives conditional resource creation and tagging.
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Name Prefix Variable --- #
# Prefix for resource names, ensuring unique and identifiable resources, particularly in shared AWS accounts.
variable "name_prefix" {
  description = "Name prefix for S3 resources. This ensures unique and identifiable resource names."
  type        = string
}

# --- AWS Account ID Variable --- #
# Used for configuring bucket policies and ensuring access is restricted to this AWS account.
variable "aws_account_id" {
  description = "AWS Account ID for configuring S3 bucket policies and ensuring resource security."
  type        = string
}

# --- KMS Key ARN Variable --- #
# Specifies the ARN of the KMS key for encrypting S3 bucket data at rest.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting S3 buckets to enhance security."
  type        = string
}

# --- Lifecycle Configuration Variable --- #
# Retention period for noncurrent object versions (applies only to buckets with versioning enabled).
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions in S3 buckets for versioning."
  type        = number
  validation {
    condition     = var.noncurrent_version_retention_days > 0
    error_message = "Retention days must be greater than 0."
  }
}

# --- SNS Topic ARN Variable --- #
# Specifies the ARN of the SNS Topic for bucket notifications.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for bucket notifications."
  type        = string
}

# --- Bucket Toggles --- #

# Enable or disable the Terraform state bucket.
variable "enable_terraform_state_bucket" {
  description = "Enable or disable the Terraform state bucket"
  type        = bool
  default     = false
}

# Enable or disable the WordPress media bucket.
variable "enable_wordpress_media_bucket" {
  description = "Enable or disable the WordPress media bucket"
  type        = bool
  default     = false
}

# Enable or disable the replication bucket.
variable "enable_replication_bucket" {
  description = "Enable or disable the replication bucket"
  type        = bool
  default     = false
}

# --- Enable Replication Variable --- #
# Enable cross-region replication for S3 buckets.
variable "enable_s3_replication" {
  description = "Enable cross-region replication for S3 buckets."
  type        = bool
  default     = false
}

# --- Buckets Variable --- #
# Core variable defining the S3 buckets for the module, driving all bucket creation and configuration.
variable "buckets" {
  description = "Map of bucket names and their types."
  type        = map(string)
}

# Enable versioning for specific buckets
# Allows fine-grained control over which buckets have versioning enabled.
# Example:
# enable_versioning = {
#   "scripts"         = true,
#   "logging"         = false,
#   "ami"             = true,
#   "terraform_state" = false,
#   "wordpress_media" = true
# }
# Versioning settings are managed in the `dev.tfvars` file for dev environment.
variable "enable_versioning" {
  description = "Map of bucket names to enable or disable versioning."
  type        = map(bool)
  default     = {}
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `dev.tfvars` to enable CORS for the WordPress media bucket
}