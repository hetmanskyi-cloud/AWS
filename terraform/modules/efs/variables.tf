# --- EFS Module Variables --- #
# This file defines all configurable variables for the Elastic File System (EFS) module.

# --- General Configuration --- #

variable "name_prefix" {
  description = "Prefix for naming all resources for easier organization (e.g., 'wordpress')."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'stage', 'prod')."
  type        = string

  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

variable "tags" {
  description = "A map of tags to assign to all resources created by this module."
  type        = map(string)
  default     = {}
}

# --- Network Configuration --- #

variable "vpc_id" {
  description = "ID of the VPC where the EFS security group will be created."
  type        = string
}

variable "subnet_ids_map" {
  description = "A map of subnet IDs where EFS mount targets will be created. Keys are static names, values are subnet IDs."
  type        = map(string)
}

variable "asg_security_group_id" {
  description = "The ID of the security group used by ASG instances that need to access this EFS."
  type        = string
}

# --- EFS File System Configuration --- #

variable "efs_encrypted" {
  description = "A boolean flag to enable/disable at-rest encryption for the EFS file system. Recommended: true."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "The ARN of the AWS KMS key to be used for encryption. Required if 'encrypted' is true."
  type        = string
  default     = ""

  validation {
    condition     = !var.efs_encrypted || (var.efs_encrypted && length(var.kms_key_arn) > 0)
    error_message = "kms_key_arn must be provided when encrypted is set to true."
  }
}

variable "performance_mode" {
  description = "The performance mode of the file system. Can be 'generalPurpose' or 'maxIO'."
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "Allowed values for performance_mode are 'generalPurpose' or 'maxIO'."
  }
}

variable "throughput_mode" {
  description = "The throughput mode for the file system. Can be 'bursting', 'provisioned', or 'elastic'."
  type        = string
  default     = "bursting"

  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "Allowed values for throughput_mode are 'bursting', 'provisioned', or 'elastic'."
  }
}

variable "provisioned_throughput_in_mibps" {
  description = "The throughput, in MiB/s, that you want to provision for the file system. Only applicable with 'throughput_mode' set to 'provisioned'."
  type        = number
  default     = null
}

# --- EFS Lifecycle Policy Configuration --- #

variable "enable_efs_lifecycle_policy" {
  description = "A boolean flag to enable/disable the EFS lifecycle policy for cost savings."
  type        = bool
  default     = false
}

variable "transition_to_ia" {
  description = "Specifies when to transition files to the IA storage class."
  type        = string
  default     = "AFTER_30_DAYS"

  validation {
    condition = contains([
      "AFTER_1_DAY", "AFTER_7_DAYS", "AFTER_14_DAYS",
      "AFTER_30_DAYS", "AFTER_60_DAYS", "AFTER_90_DAYS",
      "AFTER_180_DAYS", "AFTER_270_DAYS", "AFTER_365_DAYS"
    ], var.transition_to_ia)
    error_message = "transition_to_ia must be one of the predefined AWS values."
  }
}

# --- EFS File System Policy Configuration --- #

variable "enable_efs_policy" {
  description = "If true, a default restrictive EFS file system policy will be created to enforce in-transit encryption."
  type        = bool
  default     = true
}

# --- Monitoring & Alarms Configuration --- #

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to which CloudWatch alarm notifications will be sent."
  type        = string
}

variable "enable_burst_credit_alarm" {
  description = "If true, creates a CloudWatch alarm for low EFS burst credits. Only applicable for 'bursting' throughput mode."
  type        = bool
  default     = true
}

variable "burst_credit_threshold" {
  description = "The threshold (in bytes) for the low burst credit balance alarm. Default corresponds to ~1 TiB."
  type        = number
  default     = 1099511627776
}

# --- EFS Access Point Configuration --- #

variable "efs_access_point_path" {
  description = "The path on the EFS file system that the Access Point provides access to."
  type        = string
  default     = "/wordpress"
}

variable "efs_access_point_posix_uid" {
  description = "The POSIX user ID to apply to the Access Point."
  type        = string
  default     = "33" # User ID for www-data on Ubuntu/Debian
}

variable "efs_access_point_posix_gid" {
  description = "The POSIX group ID to apply to the Access Point."
  type        = string
  default     = "33" # Group ID for www-data on Ubuntu/Debian
}

# --- Notes --- #
# 1. **High Availability**:
#    - To ensure high availability, provide subnet IDs from at least two different Availability Zones to the `subnet_ids` variable.
#
# 2. **Security**:
#    - It is strongly recommended to keep `encrypted = true` and provide a `kms_key_arn` from your KMS module.
#    - The `asg_security_group_id` input is critical for establishing the network path between your EC2 instances and the EFS mount targets.
#    - The default file system policy (`enable_efs_policy = true`) enforces TLS encryption for all connections, which is a security best practice.
#
# 3. **Performance & Cost**:
#    - For most web applications like WordPress, the default `performance_mode = "generalPurpose"` and `throughput_mode = "bursting"` are suitable and cost-effective.
#    - Consider enabling the `lifecycle_policy` to automatically transition older, less-accessed files (e.g., old media uploads) to the cheaper Infrequent Access (IA) storage class.
#
# 4. **Dependencies**:
#    - This module expects to receive the `vpc_id` from the VPC module, `subnet_ids` from the VPC module, and `asg_security_group_id` from the ASG module.
