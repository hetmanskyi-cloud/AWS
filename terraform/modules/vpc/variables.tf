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

  validation {
    # This rule ensures that if HA NAT Gateways are enabled, every private subnet has a corresponding
    # public subnet in the same Availability Zone to host the NAT Gateway.
    condition = !var.enable_nat_gateway || var.single_nat_gateway || alltrue([
      for pvt_subnet in var.private_subnets : contains(
        [for pub_subnet in var.public_subnets : pub_subnet.availability_zone],
        pvt_subnet.availability_zone
      )
    ])
    error_message = "When High Availability NAT Gateways are enabled (enable_nat_gateway=true, single_nat_gateway=false), each private subnet's Availability Zone must have a corresponding public subnet in the same AZ."
  }
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

# --- SNS Topic ARN for CloudWatch Alarms --- #

variable "sns_topic_arn" {
  description = "ARN of SNS Topic for CloudWatch Alarms notifications."
  type        = string
  default     = null
}

# --- VPC DNS Configuration --- #

variable "enable_dns_hostnames" {
  description = "Set to true to ensure that instances launched in the VPC get DNS hostnames."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Set to true to ensure that DNS resolution is supported for the VPC."
  type        = bool
  default     = true
}

# --- VPC Flow Logs Configuration Variables --- #

variable "vpc_flow_log_traffic_type" {
  description = "The type of traffic to capture in VPC Flow Logs. Valid values: ALL, ACCEPT, REJECT."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.vpc_flow_log_traffic_type)
    error_message = "The traffic_type for VPC Flow Logs must be one of: ALL, ACCEPT, REJECT."
  }
}

# --- Network ACL Rules Configuration --- #

variable "public_nacl_rules" {
  description = "A map of Network ACL rules for the public NACL."
  type = map(object({
    rule_number = number
    egress      = bool
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_block  = string
    rule_action = string
  }))

  default = {
    "public_inbound_http" = {
      rule_number = 100
      egress      = false
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "public_inbound_https" = {
      rule_number = 110
      egress      = false
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "public_inbound_ephemeral" = {
      rule_number = 120
      egress      = false
      protocol    = "tcp"
      from_port   = 1024
      to_port     = 65535
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "public_inbound_nfs" = {
      rule_number = 130
      egress      = false
      protocol    = "tcp"
      from_port   = 2049
      to_port     = 2049
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "public_outbound_allow_all" = {
      rule_number = 200
      egress      = true
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    }
  }
}

variable "private_nacl_rules" {
  description = "A map of Network ACL rules for the private NACL."
  type = map(object({
    rule_number = number
    egress      = bool
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_block  = string
    rule_action = string
  }))

  default = {
    "private_inbound_http_from_alb" = {
      rule_number = 300
      egress      = false
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_inbound_mysql" = {
      rule_number = 310
      egress      = false
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_inbound_elasticache" = {
      rule_number = 320
      egress      = false
      protocol    = "tcp"
      from_port   = 6379
      to_port     = 6379
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_inbound_https_endpoints" = {
      rule_number = 330
      egress      = false
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_inbound_ephemeral" = {
      rule_number = 340
      egress      = false
      protocol    = "tcp"
      from_port   = 1024
      to_port     = 65535
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "private_outbound_mysql" = {
      rule_number = 400
      egress      = true
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_outbound_elasticache" = {
      rule_number = 410
      egress      = true
      protocol    = "tcp"
      from_port   = 6379
      to_port     = 6379
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_outbound_dns_tcp" = {
      rule_number = 420
      egress      = true
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "private_outbound_dns_udp" = {
      rule_number = 430
      egress      = true
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "private_outbound_ephemeral" = {
      rule_number = 440
      egress      = true
      protocol    = "tcp"
      from_port   = 1024
      to_port     = 65535
      cidr_block  = "VPC_CIDR"
      rule_action = "allow"
    },
    "private_outbound_https" = {
      rule_number = 450
      egress      = true
      protocol    = "tcp"
      from_port   = 443 # 443 outbound (includes SSM, AWS APIs, package repos)
      to_port     = 443
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    },
    "private_outbound_http" = {
      rule_number = 460
      egress      = true
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_block  = "0.0.0.0/0"
      rule_action = "allow"
    }
  }
}

# --- Notes --- #

# 1. Variables are structured to allow flexible configuration of the VPC, subnets, and associated resources.
# 2. Ensure default values for variables are set appropriately for each environment (e.g., dev, stage).
# 3. Use validations where applicable to enforce consistent and expected values.
# 4. Regularly update variable descriptions to reflect changes in module functionality.
# 5. Ensure KMS key provided has correct permissions for CloudWatch Logs (logs service principal).
# 6. Flow Logs require proper KMS encryption and retention configuration for compliance.
