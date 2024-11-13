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
  description = "Environment label for organizing resources"
  type        = string
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
variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch logs before deletion"
  type        = number
}

# --- SSH Access Configuration ---
# Enable or disable SSH access to EC2 instances (recommended to disable in production)
variable "enable_ssh_access" {
  description = "Enable or disable SSH access to EC2 instances"
  type        = bool
  default     = false
}
