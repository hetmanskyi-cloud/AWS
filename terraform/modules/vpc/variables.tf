# --- VPC Module Variables --- #

# AWS region for resource creation
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# AWS account ID for permissions and KMS policies
variable "aws_account_id" {
  description = "AWS account ID for configuring permissions in policies"
  type        = string
}

# CIDR block for the VPC
variable "vpc_cidr_block" {
  description = "Primary CIDR block for the VPC"
  type        = string
}

# Name prefix for naming resources
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# Environment label (e.g., dev, prod)
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

# --- NAT Gateway Configuration Variables --- #

variable "enable_nat_gateway" {
  description = "Set to true to enable NAT Gateway for outbound internet access from private subnets."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Set to true to create a single NAT Gateway. If false, a NAT Gateway is created in each Availability Zone for high availability."
  type        = bool
  default     = false
}

# --- Subnet Configuration Variables --- #

variable "public_subnets" {
  description = "A map of public subnets to create. The key is a logical name for the subnet, and the value is an object with cidr_block and availability_zone."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {}
}

variable "private_subnets" {
  description = "A map of private subnets to create. The key is a logical name for the subnet, and the value is an object with cidr_block and availability_zone."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {}
}

# --- VPC Flow Logs Configuration Variables --- #

# KMS key ARN used for encrypting resources like CloudWatch Logs
variable "kms_key_arn" {
  description = "KMS key ARN for encrypting Flow Logs"
  type        = string
}

# Specifies how long CloudWatch logs will be retained in days before deletion
variable "flow_logs_retention_in_days" {
  description = "Number of days to retain CloudWatch logs before deletion"
  type        = number
}

# List of allowed CIDR blocks for SSH access to ASG instances
# Recommended: Restrict in production via terraform.tfvars
variable "ssh_allowed_cidr" {
  description = "List of allowed CIDR blocks for SSH access to ASG instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for development, restrict in production
}

# --- SNS Topic ARN for CloudWatch Alarms --- #
variable "sns_topic_arn" {
  description = "ARN of SNS Topic for CloudWatch Alarms notifications."
  type        = string
  default     = null
}

# --- Notes --- #
# 1. Variables are structured to allow flexible configuration of the VPC, subnets, and associated resources.
# 2. Ensure default values for variables are set appropriately for each environment (e.g., dev, prod).
# 3. Use validations where applicable to enforce consistent and expected values.
# 4. Regularly update variable descriptions to reflect changes in module functionality.
# 5. Ensure KMS key provided has correct permissions for CloudWatch Logs (logs service principal).
# 6. Flow Logs require proper KMS encryption and retention configuration for compliance.
