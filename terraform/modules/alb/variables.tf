# --- General Variables --- #
# Prefix for naming resources, used for easy identification.
variable "name_prefix" {
  description = "Prefix for naming resources for easier organization"
  type        = string
}

# Environment label (e.g., dev, stage, prod) for tagging and organizing resources.
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- ALB Configuration --- #

# List of public subnet IDs for ALB placement.
variable "public_subnets" {
  description = "List of public subnet IDs for ALB placement"
  type        = list(string)
}

# VPC ID for the ALB and target group.
variable "vpc_id" {
  description = "VPC ID for the ALB and target group"
  type        = string
}

# Port for the target group (default: 80).
variable "target_group_port" {
  description = "Port for the target group"
  type        = number
  default     = 80
}

# ARN of the SSL certificate for HTTPS listener (optional).
variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null

  validation {
    condition     = var.enable_https_listener ? can(length(var.certificate_arn)) : true
    error_message = "Certificate ARN must be provided if HTTPS listener is enabled."
  }
}

# --- Deletion Protection Variable for ALB --- #
# This variable is specific to the ALB module and controls deletion protection for the ALB.
# - Default value: false (in `alb/variables.tf`).
# - Recommended: Set to true for production (prod) in `terraform.tfvars` for enhanced safety.
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the ALB (recommended for prod)"
  type        = bool
  default     = false
}

# --- Logging Configuration --- #
# S3 bucket name for storing ALB access logs.
variable "logging_bucket" {
  description = "S3 bucket name for storing ALB access logs"
  type        = string
}

# --- Logging Bucket ARN --- #
# ARN of the S3 bucket for Firehose logging.
variable "logging_bucket_arn" {
  description = "ARN of the S3 bucket for Firehose logging"
  type        = string

  validation {
    condition     = length(var.logging_bucket_arn) > 0
    error_message = "The logging_bucket_arn variable cannot be empty."
  }
}

# --- KMS Key ARN --- #
# ARN of the KMS key used for encrypting Firehose data in the S3 bucket.
# kms_key_arn is required if enable_firehose is set to true.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Firehose data in the S3 bucket"
  type        = string

  validation {
    condition     = var.enable_firehose ? (length(var.kms_key_arn) > 0) : true
    error_message = "kms_key_arn must be provided if enable_firehose is set to true."
  }
}

# --- Alarm and Monitoring Configuration --- #
# Threshold for high request count on ALB.
variable "alb_request_count_threshold" {
  description = "Threshold for high request count on ALB"
  type        = number
  default     = 1000
}

# Threshold for 5XX errors on ALB.
variable "alb_5xx_threshold" {
  description = "Threshold for 5XX errors on ALB"
  type        = number
  default     = 50
}

# ARN of the SNS Topic for sending CloudWatch alarm notifications.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# Enable or disable HTTPS Listener
variable "enable_https_listener" {
  description = "Enable or disable the creation of the HTTPS Listener"
  type        = bool
  default     = false
}

# Enable or disable ALB access logs
variable "enable_alb_access_logs" {
  description = "Enable or disable ALB access logs"
  type        = bool
  default     = false # Logging is unabled by default
}

# --- Enable High Request Count Alarm --- #
# Controls the creation of a CloudWatch Alarm for high request count on the ALB.
# true: The metric is created. false: The metric is not created.
variable "enable_high_request_alarm" {
  description = "Enable or disable the CloudWatch alarm for high request count on the ALB."
  type        = bool
  default     = false
}

# --- Enable 5XX Error Alarm --- #
# Controls the creation of a CloudWatch Alarm for HTTP 5XX errors on the ALB.
# true: The metric is created. false: The metric is not created.
variable "enable_5xx_alarm" {
  description = "Enable or disable the CloudWatch alarm for HTTP 5XX errors on the ALB."
  type        = bool
  default     = false
}

# --- Enable Target Response Time Alarm --- #
# Controls the creation of a CloudWatch Alarm for Target Response Time.
# true: The metric is created. false: The metric is not created.
variable "enable_target_response_time_alarm" {
  description = "Enable or disable the CloudWatch alarm for Target Response Time."
  type        = bool
  default     = false
}

# --- Enable Health Check Failed Alarm --- #
# Controls the creation of a CloudWatch Alarm for ALB health check failures.
# true: The alarm is created. false: The alarm is not created.
variable "enable_health_check_failed_alarm" {
  description = "Enable or disable the CloudWatch alarm for ALB health check failures."
  type        = bool
  default     = false
}

# Toggle WAF for ALB
variable "enable_waf" {
  description = "Enable or disable WAF for ALB" # Description of the variable
  type        = bool                            # Boolean type for true/false values
  default     = false                           # Default value is false
}

# --- Enable WAF Logging --- #
# This variable controls the creation of WAF logging resources. WAF logging will be enabled only if:
# 1. `enable_waf_logging` is set to true.
# 2. Firehose (`enable_firehose`) is also enabled, as it is required for delivering logs.
# By default, WAF logging is disabled.
variable "enable_waf_logging" {
  description = "Enable or disable logging for WAF independently of WAF enablement"
  type        = bool
  default     = false
}

# Enable or disable Firehose and related resources
variable "enable_firehose" {
  description = "Enable or disable Firehose and related resources"
  type        = bool
  default     = false
}