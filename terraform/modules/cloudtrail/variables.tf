variable "name_prefix" {
  description = "Prefix for naming CloudTrail resources"
  type        = string
}

variable "environment" {
  description = "Environment for tagging resources (e.g., dev, prod)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the existing S3 bucket for storing CloudTrail logs"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9.-]+$", var.s3_bucket_arn))
    error_message = "The s3_bucket_arn must be a valid S3 bucket ARN."
  }
}

variable "enable_logging" {
  description = "Enable or disable CloudTrail logging"
  type        = bool
  default     = true
}

variable "multi_region_trail" {
  description = "Enable multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Include global service events in CloudTrail"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encrypting CloudTrail logs"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudTrail notifications"
  type        = string
  default     = null
}

variable "log_file_validation_enabled" {
  description = "Enable log file validation for CloudTrail"
  type        = bool
  default     = true
}
