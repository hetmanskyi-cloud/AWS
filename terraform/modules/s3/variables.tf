# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module, allowing customization and flexibility.

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

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "The kms_key_arn variable cannot be empty."
  }
}

# Enable or disable the creation of the IAM role for managing the KMS key
variable "enable_kms_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}

# --- Enable KMS Role for S3 --- #
# This variable controls whether the IAM role and policy for KMS interaction in the S3 module are created.
variable "enable_kms_s3_role" {
  description = "Enable or disable the creation of IAM role and policy for S3 to access KMS."
  type        = bool
  default     = false # Set to true in terraform.tfvars if S3 needs a dedicated KMS role.
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
# Example for `buckets`:
# {
#   "scripts"         = "base",
#   "logging"         = "special",
#   "ami"             = "base",
#   "terraform_state" = "special",
#   "wordpress_media" = "special"
#   "replication"     = "special"
# }

# --- Versioning Configuration --- #

# Versioning settings are managed in the `terraform.tfvars` file.
variable "enable_versioning" {
  description = "Map of bucket names to enable or disable versioning."
  type        = map(bool)
  default     = {}
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# --- Enable DynamoDB for State Locking --- #
# This variable controls whether the DynamoDB table for Terraform state locking is created.
# - true: Creates the DynamoDB table and associated resources for state locking.
# - false: Skips the creation of DynamoDB-related resources.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for Terraform state locking."
  type        = bool
  default     = false

  # --- Notes --- #
  # 1. When enabled, the module creates a DynamoDB table with TTL and stream configuration.
  # 2. This is required only if you are using DynamoDB-based state locking.
  # 3. If you prefer S3 Conditional Writes for state locking, set this to false.
}

# --- Enable Lambda for TTL Automation --- #
# This variable controls whether the Lambda function for TTL automation is created.
# - true: Creates the Lambda function and associated resources.
# - false: Skips the creation of Lambda-related resources.
variable "enable_lambda" {
  description = "Enable Lambda function for DynamoDB TTL automation."
  type        = bool
  default     = false

  # --- Notes --- #
  # 1. This variable must be set to true only if `enable_dynamodb = true`.
  # 2. When disabled, all Lambda-related resources (IAM role, policy, function, etc.) are skipped.
}