# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Configuration ---#
# Region where the replication bucket will be created, typically different from the primary region.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string

  validation {
    condition     = var.replication_region == "us-east-1" || var.replication_region == "eu-west-1"
    error_message = "Replication region must be one of 'us-east-1' or 'eu-west-1'."
  }
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
#   "logging"         = "base",
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

  validation {
    condition     = alltrue([for key in keys(var.enable_versioning) : contains(keys(var.buckets), key)])
    error_message = "All keys in enable_versioning must exist in buckets."
  }
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# --- Enable DynamoDB for State Locking --- #
# Controls the creation of the DynamoDB table for state locking.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for state locking."
  type        = bool
  default     = false

  # --- Validation --- #
  # Ensures DynamoDB is only enabled when S3 bucket are active.
  validation {
    condition     = var.enable_dynamodb ? var.enable_terraform_state_bucket : true
    error_message = "enable_dynamodb requires enable_terraform_state_bucket = true."
  }

  # --- Notes --- #
  # 1. Required for state locking in remote backend setups.
  # 2. Creates a DynamoDB table with TTL and stream configuration.
  # 3. Skipped if state locking is managed differently or not required.
}

# --- Enable Lambda for TTL Automation --- #
# Enables Lambda for DynamoDB TTL cleanup.
variable "enable_lambda" {
  description = "Enable Lambda for DynamoDB TTL automation."
  type        = bool
  default     = false

  # --- Validation --- #
  # Ensures Lambda is enabled only if DynamoDB is active.
  validation {
    condition     = var.enable_lambda ? var.enable_dynamodb : true
    error_message = "enable_lambda requires enable_dynamodb = true."
  }

  # --- Notes --- #
  # 1. Required for state locking in remote backend setups.
  # 2. This variable requires enable_dynamodb to be true to create Lambda resources.
  # 3. The Lambda function automates the cleanup of expired locks in the DynamoDB table.
  # 4. Set to false if DynamoDB TTL automation is not required or managed differently.
}