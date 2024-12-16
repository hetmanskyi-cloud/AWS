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
# Name of the ALB.
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

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

# Security Group ID for the ALB.
variable "alb_sg_id" {
  description = "Security Group ID for the ALB"
  type        = string
}

# Port for the target group (default: 80).
variable "target_group_port" {
  description = "Port for the target group"
  type        = number
  default     = 80
}

# ARN of the SSL certificate for HTTPS listener (optional).
# Note: In dev, SSL certificate is not required.
variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null

  validation {
    condition     = var.environment == "dev" || can(length(var.certificate_arn))
    error_message = "In stage and prod, 'certificate_arn' cannot be empty."
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
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Firehose data in the S3 bucket"
  type        = string

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "The kms_key_arn variable cannot be empty."
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

# --- Notes --- #
# 1. Variables `name_prefix`, `environment`, `public_subnets`, and `vpc_id` are mandatory for all environments.
# 2. Logging-related variables (`logging_bucket`, `logging_bucket_arn`, `kms_key_arn`) are used in stage and prod only.
# 3. `alb_request_count_threshold` and `alb_5xx_threshold` control alarm sensitivity; these can be adjusted based on the expected traffic.
# 4. `certificate_arn` is required for HTTPS configuration in stage and prod.