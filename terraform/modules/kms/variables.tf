# --- KMS Module Variables --- #

# AWS Account ID for configuring permissions in the KMS key policy
# This is necessary for allowing the root account access to the KMS key.
variable "aws_account_id" {
  description = "AWS Account ID for configuring permissions in the KMS key policy"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The AWS Account ID must be a 12-digit number."
  }
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

# --- Enable Key Rotation --- #
# Allows enabling or disabling automatic key rotation for the KMS key.
variable "enable_key_rotation" {
  description = "Enable or disable automatic key rotation for the KMS key"
  type        = bool
  default     = true
}

# List of additional AWS principals that require access to the KMS key
# Useful for allowing specific IAM roles or services access to the key, expanding beyond the root account and logs service.
variable "additional_principals" {
  description = <<EOT
  List of additional AWS principals (e.g., IAM roles or services) that require access to the KMS key.
  Example:
    - "arn:aws:iam::123456789012:role/example-role"
    - "arn:aws:iam::123456789012:role/another-role"
  Leave this as an empty list if no additional principals need to be granted access initially.
  EOT
  type        = list(string)
  default     = [] # Default is an empty list, meaning no additional principals
}

# Enable or disable the creation of the IAM role for managing the KMS key
# Set to true to create the IAM role and its associated policy for managing the KMS key.
variable "enable_kms_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}

# --- Enable CloudWatch Monitoring --- #
# This variable controls whether CloudWatch Alarms for the KMS key usage are created.
variable "enable_key_monitoring" {
  description = "Enable or disable CloudWatch Alarms for monitoring KMS key usage."
  type        = bool
  default     = false
}

# --- Threshold for Decrypt Operations --- #
# Defines the threshold for the number of Decrypt operations that trigger a CloudWatch Alarm.
variable "key_decrypt_threshold" {
  description = "Threshold for KMS decrypt operations to trigger an alarm."
  type        = number
  default     = 100 # Example value, adjust as needed.

  validation {
    condition     = var.key_decrypt_threshold > 0
    error_message = "Threshold must be greater than 0."
  }
}

# --- Enable KMS Alias Creation --- #
# This variable controls whether an alias is created for the KMS key.
variable "enable_kms_alias" {
  description = "Enable or disable the creation of a KMS alias."
  type        = bool
  default     = false
}

# ARN of the SNS Topic for CloudWatch alarms.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}