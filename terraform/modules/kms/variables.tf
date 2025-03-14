# --- KMS Module Variables --- #

# AWS Account ID for configuring permissions in the KMS key policy
# This is necessary for allowing the root account access to the KMS key.
variable "aws_account_id" {
  description = "AWS Account ID for configuring permissions in the KMS key policy"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The AWS Account ID must be a 12-digit numeric string."
  }
}

# AWS Region where the resources are created
# Used to define the region-specific policy in the KMS key settings.
variable "aws_region" {
  description = "AWS Region where the resources are created"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "The AWS Region must follow the format 'xx-xxxx-x', e.g., 'eu-west-1'."
  }
}

# Replication region for S3
variable "replication_region" {
  description = "AWS Region for S3 replication (if used)"
  type        = string
  default     = ""

  validation {
    condition     = var.replication_region == "" || can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.replication_region))
    error_message = "The replication region must follow the format 'xx-xxxx-x', e.g., 'eu-west-1'."
  }
}

# Prefix for naming KMS and related resources
# Helps organize resources with a consistent naming convention across environments.
variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0
    error_message = "The name_prefix variable cannot be empty."
  }
}

# Environment label for tracking resources (dev, stage, prod)
# Adds an environment-specific tag to the KMS key for easier organization and filtering.
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# S3 bucket configuration for default region.
variable "default_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, false)
    replication = optional(bool, false)
    logging     = optional(bool, false)
    region      = optional(string, null) # Optional region, defaults to provider region if not set
  }))
  description = "Configuration for S3 buckets in the default AWS region."
  default     = {}
}

# S3 bucket configuration for replication region.
variable "replication_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, true)  # Versioning MUST be enabled for replication destinations
    replication = optional(bool, false) # Replication is not applicable for replication buckets themselves
    logging     = optional(bool, false)
    region      = string # AWS region for the replication bucket (REQUIRED)
  }))
  description = "Configuration for S3 buckets specifically in the replication AWS region."
  default     = {}
}

# Enable Key Rotation
# Controls whether automatic key rotation is enabled for the KMS key.
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
  - "arn:aws:iam::123456789012:user/example-user"
Leave this as an empty list if no additional principals need to be granted access initially.
EOT
  type        = list(string)
  default     = [] # Default is an empty list, meaning no additional principals

  validation {
    condition     = alltrue([for arn in var.additional_principals : can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/[A-Za-z0-9-_]+$", arn))])
    error_message = "All additional principals must be valid IAM ARNs."
  }
}

# Enable or disable the creation of the IAM role for managing the KMS key
# Set to true to create the IAM role and its associated policy for managing the KMS key.
variable "enable_kms_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}

# Enable Key Monitoring
# This variable controls whether CloudWatch Alarms for the KMS key usage are created.
variable "enable_key_monitoring" {
  description = "Enable or disable CloudWatch Alarms for monitoring KMS key usage."
  type        = bool
  default     = false
}

# Decrypt Operations Threshold
# Sets the threshold for the number of decrypt operations that trigger an alarm.
variable "key_decrypt_threshold" {
  description = "Threshold for KMS decrypt operations to trigger an alarm."
  type        = number
  default     = 100 # Example value, adjust as needed.

  validation {
    condition     = var.key_decrypt_threshold > 0 && floor(var.key_decrypt_threshold) == var.key_decrypt_threshold
    error_message = "Threshold must be a positive integer greater than 0."
  }
}

# ARN of the SNS Topic for CloudWatch alarms.
# Specifies the SNS topic to send CloudWatch alarm notifications.
# This is mandatory if `enable_key_monitoring` is true.
variable "sns_topic_arn" {
  description = <<EOT
ARN of the SNS Topic for sending CloudWatch alarm notifications.
This is mandatory if `enable_key_monitoring` is true.
EOT
  type        = string
  default     = ""

  validation {
    condition     = !(var.enable_key_monitoring && var.sns_topic_arn == "") && can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9-_]+$", var.sns_topic_arn))
    error_message = "The SNS Topic ARN must be a valid ARN in the format 'arn:aws:sns:<region>:<account_id>:<topic_name>'. It is mandatory when `enable_key_monitoring` is true."
  }
}

# Enable DynamoDB
# Indicates if permissions for DynamoDB should be added to the KMS key.
variable "enable_dynamodb" {
  description = "Flag to indicate if DynamoDB is enabled for state locking"
  type        = bool
  default     = false
}

# Enable Firehose
# Controls whether permissions for Kinesis Firehose are added to the KMS key.
variable "enable_firehose" {
  description = "Enable permissions for Kinesis Firehose to use the KMS key"
  type        = bool
  default     = false
}

# Enable WAF Logging
# Controls whether permissions for WAF logging are added to the KMS key.
variable "enable_waf_logging" {
  description = "Enable permissions for WAF logging to use the KMS key"
  type        = bool
  default     = false
}