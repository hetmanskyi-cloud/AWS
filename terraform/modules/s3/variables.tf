# --- S3 Module Variables --- #
# This file defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Configuration ---#
# Defines the AWS region where the replication bucket will be created.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- Environment Variable --- #
# Defines the environment in which the resources are deployed (e.g., dev, stage, prod).
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Name Prefix Variable --- #
# Prefix used for naming S3 resources to ensure consistency and avoid name conflicts.
variable "name_prefix" {
  description = "Name prefix for S3 resources. This ensures unique and identifiable resource names."
  type        = string
}

# --- AWS Account ID Variable --- #
# Used for configuring bucket policies to restrict access to the specified AWS account.
variable "aws_account_id" {
  description = "AWS Account ID for configuring S3 bucket policies and ensuring resource security."
  type        = string
}

# --- KMS Key ARN Variable --- #
# Specifies the ARN of the KMS key used for encrypting S3 buckets.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting S3 buckets to enhance security."
  type        = string
}

# --- Lifecycle Configuration Variable --- #
# Number of days to retain noncurrent versions of objects in S3 buckets before they are permanently deleted.
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

# --- Enable Replication Variable --- #
# Determines whether cross-region replication is enabled for the S3 buckets.
variable "enable_s3_replication" {
  description = "Enable cross-region replication for S3 buckets."
  type        = bool
  default     = false
}

# --- Buckets Variable --- #
# Defines a list of buckets and their attributes.
# Each bucket object must include:
# - `name`: The unique name of the bucket.
# - `type`: The classification of the bucket (`base` or `special`), which determines the bucket's purpose and its configuration.
# This variable drives all dynamic bucket operations across the module.
# Example:
# buckets = [
#   { name = "terraform_state", type = "base" },
#   { name = "wordpress_media", type = "special" }
# ]
variable "buckets" {
  description = "List of buckets and their types."
  type = list(object({
    name = string
    type = string
  }))
}
