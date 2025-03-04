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

  validation {
    condition     = can(regex("^vpc-[a-f0-9]{8,17}$", var.vpc_id))
    error_message = "The VPC ID must be a valid AWS VPC ID."
  }
}

# Outputs the CIDR block of the VPC
variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr_block))
    error_message = "The VPC CIDR block must be a valid AWS CIDR block."
  }
}

# --- Private Subnet IDs --- #
# A list of private subnet IDs where Interface Endpoints will be deployed.
variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)

  validation {
    condition     = alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[a-f0-9]{8,17}$", id))])
    error_message = "All subnet IDs must be valid AWS subnet IDs."
  }
}

# --- Private Subnet CIDR Blocks --- #
# The CIDR blocks for private subnets used to define Security Group rules.
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))])
    error_message = "All CIDR blocks must be in valid format (e.g., '10.0.0.0/24')."
  }
}

# --- Public Subnet IDs --- #
# List of public subnet IDs for interface endpoints, if needed.
variable "public_subnet_ids" {
  description = "List of public subnet IDs for interface endpoints"
  type        = list(string)

  validation {
    condition     = alltrue([for id in var.public_subnet_ids : can(regex("^subnet-[a-f0-9]{8,17}$", id))])
    error_message = "All public subnet IDs must be valid AWS subnet IDs."
  }
}

# --- Public Subnet CIDR Blocks --- #
# CIDR blocks for public subnets used to define Security Group rules.
variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))])
    error_message = "All CIDR blocks must be in valid format (e.g., '10.0.0.0/24')."
  }
}

# --- Notes --- #
# 1. Variables are designed to provide flexibility and ensure compatibility across environments.
# 2. CIDR blocks and Subnet IDs are required for Security Group and Endpoint configurations.
# 3. CloudWatch Logs can be enabled for Interface Endpoints for monitoring traffic.
# 4. KMS Key ARN is required if encryption for CloudWatch Logs is enabled.
# 5. Log retention period is configurable to meet different compliance and operational requirements.