# --- Interface Endpoints Module Variables --- #

# --- AWS Region --- #
# The AWS region where all resources will be created.
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "The AWS Region must follow the format 'xx-xxxx-x', e.g., 'eu-west-1'."
  }
}

# --- Name Prefix --- #
# A prefix applied to all resource names for easy identification.
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0
    error_message = "The name_prefix variable cannot be empty."
  }
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

# Tags for resource identification and management
variable "tags" {
  description = "Component-level tags used for identifying resource ownership"
  type        = map(string)
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

# --- VPC CIDR Block --- #
# The CIDR block of the VPC. Used to configure Security Group rules.
variable "vpc_cidr_block" {
  description = "The CIDR block of the VPC. Used to configure Security Group rules."
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
    condition     = !var.enable_interface_endpoints || length(var.private_subnet_ids) > 0
    error_message = "At least one private subnet ID must be provided when enable_interface_endpoints is true."
  }
}

# --- Enable or Disable Interface VPC Endpoints --- #
# This variable controls whether Interface VPC Endpoints (SSM, CloudWatch, KMS, etc.)
# are created within the VPC. When set to `false`, no Interface Endpoints or
# associated resources (such as Security Groups) will be created.
variable "enable_interface_endpoints" {
  description = "Enable or disable the creation of all Interface VPC Endpoints and related resources."
  type        = bool
  default     = false
}

variable "interface_endpoint_services" {
  description = <<-EOT
  A list of AWS services for which to create interface endpoints. The default is an empty list,
  meaning you MUST provide a list of services for this module to be useful.

  WARNING: Enabling endpoints changes DNS resolution within the VPC to use private IPs for these services.
  If an instance needs to contact an AWS service (e.g., secretsmanager, ssm, ec2), its corresponding endpoint MUST be included in this list.
  Failure to do so will result in connection timeouts, as the system will not fall back to using a NAT Gateway for that service.

  See this module's README.md for a recommended list of services for typical EC2-based workloads.
  EOT
  type        = list(string)
  default     = []
}
# --- Notes --- #
# 1. Variables are designed to provide flexibility and ensure compatibility across environments.
# 2. CIDR blocks and Subnet IDs are required for Security Group and Endpoint configurations.
