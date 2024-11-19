# --- S3 Module Variables --- #

# Environment for the resources (dev, stage, prod)
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
}

# Name prefix for S3 resources
variable "name_prefix" {
  description = "Name prefix for S3 resources"
  type        = string
}

# --- AWS Account ID Variable --- #
variable "aws_account_id" {
  description = "AWS Account ID for configuring S3 bucket policies and other resources"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 bucket encryption"
  type        = string
}

# --- Lifecycle Configuration --- #
# Number of days to retain noncurrent object versions
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent versions of objects in S3 buckets"
  type        = number
}
