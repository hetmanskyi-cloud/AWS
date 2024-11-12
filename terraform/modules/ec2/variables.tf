# --- EC2 Instance Configuration Variables --- #

# AMI ID to be used for the EC2 instances.
variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID for the EC2 instances"
  type        = string
}

# Instance type for EC2. Defaulted to t2.micro for development.
variable "instance_type" {
  description = "EC2 instance type (e.g., t2.micro)"
  type        = string
}

# SSH key name for accessing the EC2 instances.
variable "ssh_key_name" {
  description = "Name of the SSH key for EC2 access"
  type        = string
}

# User data script for configuring the EC2 instance at launch.
variable "user_data" {
  description = "Base64-encoded user data script for initial configuration (e.g., installing applications)"
  type        = string
}

# --- Auto Scaling Configuration Variables --- #

# Desired number of instances for the Auto Scaling Group.
variable "autoscaling_desired" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
}

# Minimum number of instances for the Auto Scaling Group.
variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
}

# Maximum number of instances for the Auto Scaling Group.
variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
}

# Threshold for scaling out (increasing instance count) when CPU utilization exceeds this value.
variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out"
  type        = number
}

# Threshold for scaling in (decreasing instance count) when CPU utilization drops below this value.
variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in"
  type        = number
}

# --- Storage Configuration Variables --- #

# Size of the root EBS volume attached to each EC2 instance.
variable "volume_size" {
  description = "Size of the EBS volume for the root device in GiB"
  type        = number
}

# Type of the EBS volume (e.g., gp2 for General Purpose SSD).
variable "volume_type" {
  description = "Type of the EBS volume for the root device"
  type        = string
}

# --- Network Configuration Variables --- #

# Public subnet IDs where the EC2 instances in the Auto Scaling Group will be launched.
variable "public_subnet_id_1" {
  description = "ID of the first public subnet for Auto Scaling Group"
  type        = string
}

variable "public_subnet_id_2" {
  description = "ID of the second public subnet for Auto Scaling Group"
  type        = string
}

variable "public_subnet_id_3" {
  description = "ID of the third public subnet for Auto Scaling Group"
  type        = string
}

# Security group ID(s) for controlling inbound/outbound traffic.
variable "security_group_id" {
  description = "Security group ID for the EC2 instance to control traffic"
  type        = list(string)
}

# --- General Configuration Variables --- #

# Prefix for naming resources, used for easy identification.
variable "name_prefix" {
  description = "Prefix for naming resources for easier organization"
  type        = string
}

# Environment label (e.g., dev, staging, prod) for tagging and organizing resources.
variable "environment" {
  description = "Environment label to organize resources (e.g., dev, staging, prod)"
  type        = string
}

# --- Security Group Variables --- #

# VPC ID where the EC2 instances are deployed
variable "vpc_id" {
  description = "ID of the VPC for Security Group association"
  type        = string
}
