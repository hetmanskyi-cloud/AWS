# --- Variables for VPC Endpoints Module --- #

# --- AWS Region --- #
# The AWS region where all resources will be created.
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS account ID for permissions and policies"
  type        = string
}

# --- Name Prefix --- #
# A prefix applied to all resource names for easy identification.
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# --- Environment Label --- #
# Specifies the environment for the resources: dev, stage, or prod.
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- VPC ID --- #
# The ID of the VPC where the VPC Endpoints will be created.
variable "vpc_id" {
  description = "The VPC ID where endpoints will be created"
  type        = string
}

# --- Private Subnet IDs --- #
# A list of private subnet IDs where Interface Endpoints will be deployed.
variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
}

# --- Private Subnet CIDR Blocks --- #
# The CIDR blocks for private subnets used to define Security Group rules.
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# --- Encryption Configuration --- #
# ARN of the KMS key used for encrypting data.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting data"
  type        = string
}

# --- Enable CloudWatch Logs for Endpoints --- #
# Enables CloudWatch Logs for monitoring VPC Endpoints.
variable "enable_cloudwatch_logs_for_endpoints" {
  description = "Enable CloudWatch Logs for VPC Endpoints in stage and prod environments"
  type        = bool
  default     = false
}

# --- Log Retention Period --- #
# Defines the retention period for CloudWatch Logs.
variable "endpoints_log_retention_in_days" {
  description = "Retention period for CloudWatch Logs in days"
  type        = number
  default     = 14

  validation {
    condition     = var.endpoints_log_retention_in_days > 0
    error_message = "Log retention period must be a positive integer."
  }
}

# --- Notes --- #
# 1. Variables are designed to provide flexibility and ensure compatibility across environments.
# 2. CIDR blocks and Subnet IDs are required for Security Group and Endpoint configurations.
# 3. CloudWatch Logs can be enabled for Interface Endpoints for monitoring traffic.
# 4. KMS Key ARN is required if encryption for CloudWatch Logs is enabled.
# 5. Log retention period is configurable to meet different compliance and operational requirements.