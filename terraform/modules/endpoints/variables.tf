# AWS region for resource creation
variable "aws_region" {
  description = "AWS region where resources will be created"
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

variable "vpc_id" {
  description = "The VPC ID where endpoints will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs for the S3 Gateway endpoint"
  type        = list(string)
}

variable "endpoint_sg_id" {
  description = "Security Group ID for interface endpoints"
  type        = string
}

