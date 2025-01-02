# --- KMS Module Variables --- #

# AWS Account ID for configuring permissions in the KMS key policy
# This is necessary for allowing the root account access to the KMS key.
variable "aws_account_id" {
  description = "AWS Account ID for configuring permissions in the KMS key policy"
  type        = string
}

# AWS Region where the resources are created
# Used to define the region-specific policy in the KMS key settings.
variable "aws_region" {
  description = "AWS Region where the resources are created"
  type        = string
}

# Prefix for naming KMS and related resources
# Helps organize resources with a consistent naming convention across environments.
variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

# Environment label for tracking resources (dev, stage, prod)
# Adds an environment-specific tag to the KMS key for easier organization and filtering.
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# List of additional AWS principals that require access to the KMS key
# Useful for allowing specific IAM roles or services access to the key, expanding beyond the root account and logs service.
variable "additional_principals" {
  description = "List of additional AWS principals (e.g., services or IAM roles) that need access to the KMS key"
  type        = list(string)
  default     = []
}

# Enable or disable the creation of the IAM role for managing the KMS key
# Set to true to create the IAM role and its associated policy for managing the KMS key.
variable "enable_kms_management_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}