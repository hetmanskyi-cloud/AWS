# --- VPC Configuration Variables --- #

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

# --- Public Subnet Configuration Variables --- #

# CIDR blocks for public subnets
variable "public_subnet_cidr_block_1" {
  description = "CIDR block for the first public subnet"
  type        = string
}

variable "public_subnet_cidr_block_2" {
  description = "CIDR block for the second public subnet"
  type        = string
}

variable "public_subnet_cidr_block_3" {
  description = "CIDR block for the third public subnet"
  type        = string
}

# Availability zones for public subnets
variable "availability_zone_public_1" {
  description = "Availability zone for the first public subnet"
  type        = string
}

variable "availability_zone_public_2" {
  description = "Availability zone for the second public subnet"
  type        = string
}

variable "availability_zone_public_3" {
  description = "Availability zone for the third public subnet"
  type        = string
}

# --- Private Subnet Configuration Variables --- #

# CIDR blocks for private subnets
variable "private_subnet_cidr_block_1" {
  description = "CIDR block for the first private subnet"
  type        = string
}

variable "private_subnet_cidr_block_2" {
  description = "CIDR block for the second private subnet"
  type        = string
}

variable "private_subnet_cidr_block_3" {
  description = "CIDR block for the third private subnet"
  type        = string
}

# Availability zones for private subnets
variable "availability_zone_private_1" {
  description = "Availability zone for the first private subnet"
  type        = string
}

variable "availability_zone_private_2" {
  description = "Availability zone for the second private subnet"
  type        = string
}

variable "availability_zone_private_3" {
  description = "Availability zone for the third private subnet"
  type        = string
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

# --- SSH Access Configuration ---
# Enable or disable SSH access
variable "enable_vpc_ssh_access" {
  description = "Enable or disable SSH access"
  type        = bool
}

variable "ssh_allowed_cidr" {
  description = "List of allowed CIDR blocks for SSH access to ASG instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for development, restrict for production
}

# Enable or disable HTTP/HTTPS rules for public NACL
variable "enable_public_nacl_http" {
  description = "Enable or disable HTTP rule for public NACL (port 80)"
  type        = bool
  default     = false
}

variable "enable_public_nacl_https" {
  description = "Enable or disable HTTPS rule for public NACL (port 443)"
  type        = bool
  default     = false
}

# --- Variables for VPC Endpoints Routes --- #

variable "ssm_endpoint_id" {
  description = "ID of the SSM Interface VPC Endpoint (from interface_endpoints module)"
  type        = string
}

variable "ssm_messages_endpoint_id" {
  description = "ID of the SSM Messages Interface VPC Endpoint (from interface_endpoints module)"
  type        = string
}

variable "asg_messages_endpoint_id" {
  description = "ID of the EC2 ASG Messages Interface Endpoint (ASG Messages) (from interface_endpoints module)"
  type        = string
}

variable "lambda_endpoint_id" {
  description = "ID of the Lambda Interface VPC Endpoint (from interface_endpoints module)"
  type        = string
}

variable "cloudwatch_logs_endpoint_id" {
  description = "ID of the CloudWatch Logs Interface VPC Endpoint (from interface_endpoints module)"
  type        = string
}

variable "sqs_endpoint_id" {
  description = "ID of the SQS Interface Endpoint (from interface_endpoints module)"
  type        = string
}

variable "kms_endpoint_id" {
  description = "ID of the KMS Interface VPC Endpoint (from interface_endpoints module)"
  type        = string
}

# --- Notes --- #
# 1. Variables are structured to allow flexible configuration of the VPC, subnets, and associated resources.
# 2. Ensure default values for variables are set appropriately for each environment (e.g., dev, prod).
# 3. Use validations where applicable to enforce consistent and expected values.
# 4. Regularly update variable descriptions to reflect changes in module functionality.