# --- S3 Module Variables --- #
# This file defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Confuguration ---#

# Replication region for the replication bucket
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- Environment Variable --- #
# Defines the environment in which the resources are deployed (e.g., dev, stage, prod)
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod). Used for tagging and naming conventions."
  type        = string
}

# --- Name Prefix Variable --- #
# Prefix used for naming S3 resources to ensure consistency and avoid name conflicts
variable "name_prefix" {
  description = "Name prefix for S3 resources. This ensures unique and identifiable resource names."
  type        = string
}

# --- AWS Account ID Variable --- #
# Used for configuring bucket policies to restrict access to the specified AWS account
variable "aws_account_id" {
  description = "AWS Account ID for configuring S3 bucket policies and ensuring resource security."
  type        = string
}

# --- KMS Key ARN Variable --- #
# Specifies the ARN of the KMS key used for encrypting S3 buckets
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting S3 buckets to enhance security."
  type        = string
}

# --- Lifecycle Configuration Variable --- #
# Number of days to retain noncurrent versions of objects in S3 buckets before they are permanently deleted
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions in S3 buckets for versioning."
  type        = number
}

variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for bucket notifications"
  type        = string
}

# --- Enable Replication Variable --- #
# Determines whether cross-region replication is enabled for the S3 buckets
variable "enable_s3_replication" {
  description = "Enable cross-region replication for S3 buckets"
  type        = bool
  default     = false
}
