# --- ALB Module Variables --- #

# Prefix for naming resources, used for easy identification.
variable "name_prefix" {
  description = "Prefix for naming resources for easier organization"
  type        = string
  validation {
    condition     = length(var.name_prefix) <= 24
    error_message = "The name_prefix must be 24 characters or less to ensure resource names don't exceed AWS limits."
  }
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

# Tags for resource identification and management
variable "tags" {
  description = "Component-level tags used for identifying resource ownership"
  type        = map(string)
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
# Required when `enable_https_listener` is set to true.
# Best practice: Use a valid ACM certificate in production for HTTPS traffic.
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
# Recommended: Set to true for production (prod) in `terraform.tfvars` to prevent accidental deletion of the ALB.
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the ALB (recommended for prod)"
  type        = bool
  default     = false
}

# --- Logging Configuration --- #

variable "alb_logs_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for ALB access logs"
}

# --- Logging Bucket ARN --- #
# ARN of the S3 bucket for Firehose logging.
variable "logging_bucket_arn" {
  description = "The ARN of the S3 bucket used for ALB access logs. If not provided, logging is disabled."
  type        = string
  default     = null

  validation {
    condition     = var.logging_bucket_arn == null ? true : length(var.logging_bucket_arn) > 0
    error_message = "If provided, logging_bucket_arn must be a non-empty string."
  }
}

# --- KMS Key ARN --- #
# ARN of the KMS key used for encrypting Firehose data in the S3 bucket.
# Customer Managed Key (CMK) is used for better security control.
# Required if enable_firehose is set to true.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Firehose data in the S3 bucket"
  type        = string

  validation {
    condition     = var.enable_alb_firehose ? (length(var.kms_key_arn) > 0) : true
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
# Critical for receiving alerts in production environments.
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
  type        = bool
  description = "Enable access logs for the ALB"
  default     = true
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

# Toggle WAF for ALB
variable "enable_alb_waf" {
  description = "Enable or disable WAF for ALB"
  type        = bool
  default     = false
}

# --- Enable WAF Logging --- #
# This variable controls the creation of WAF logging resources. WAF logging will be enabled only if:
# 1. `enable_waf_logging` is set to true.
# 2. Firehose (`enable_firehose`) is also enabled, as it is required for delivering logs.
# By default, WAF logging is disabled.
variable "enable_alb_waf_logging" {
  description = "Enable or disable logging for WAF independently of WAF enablement"
  type        = bool
  default     = false
}

# Enable or disable Firehose and related resources
variable "enable_alb_firehose" {
  description = "Enable or disable Firehose and related resources"
  type        = bool
  default     = false
}

# Enable or disable CloudWatch logging for Firehose delivery stream
variable "enable_alb_firehose_cloudwatch_logs" {
  description = "Enable CloudWatch logging for Firehose delivery stream. Useful for debugging failures."
  type        = bool
  default     = false
}

# --- Custom Header for CloudFront to ALB Communication --- #

variable "cloudfront_to_alb_secret_header_value" {
  description = "Secret value for the custom CloudFront → ALB header."
  type        = string
  sensitive   = true
}

# --- Notes --- #
# - In production, enable HTTPS listener, WAF, and logging for improved security and observability.
# - Features controlled by `enable_*` variables (e.g., enable_waf, enable_firehose, enable_high_request_alarm)
#   are optional but highly recommended for production environments:
#     - enable_waf: Protects against common web attacks.
#     - enable_firehose: Enables detailed WAF logging to S3 for auditing.
#     - enable_*_alarm: Activates CloudWatch alarms for traffic monitoring and issue detection.
# - In development or test environments, these features can be disabled to reduce costs.
# - Validate all required ARNs (certificate_arn, sns_topic_arn, kms_key_arn) before enabling related features.
# - Regularly review and adjust alarm thresholds based on real traffic patterns and system behavior.
