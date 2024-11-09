# --- AWS Region Configuration --- #
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS account ID for permissions and policies"
  type        = string
}

# --- Environment Label --- #
variable "environment" {
  description = "The environment for organizing resources (e.g., dev, prod)"
  type        = string
}

# --- Name Prefix for Resources --- #
variable "name_prefix" {
  description = "Prefix for resource names to distinguish environments"
  type        = string
}

# --- VPC Configuration --- #
# CIDR blocks for VPC and subnets
variable "vpc_cidr_block" {
  description = "Primary CIDR block for the VPC"
  type        = string
}

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

# --- Availability Zones --- #
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

# --- CloudWatch Log Retention --- #
variable "log_retention_in_days" {
  description = "Retention period in days for CloudWatch logs"
  type        = number
}

# --- Enable Key Rotation --- #
variable "enable_key_rotation" {
  description = "Enable or disable automatic key rotation for the KMS key"
  type        = bool
  default     = false
}

# --- EC2 Instance Configuration --- #

# Settings for instance, AMI, and key
variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t2.micro)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key for EC2 access"
  type        = string
}

# --- Auto Scaling Configuration --- #
variable "autoscaling_desired" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
}

variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
}

variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out"
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in"
  type        = number
}

# --- EBS Volume Configuration --- #
variable "volume_size" {
  description = "Size of the EBS volume for the root device in GiB"
  type        = number
}

variable "volume_type" {
  description = "Type of the EBS volume for the root device"
  type        = string
}

# --- SSM and SSH Access --- #
variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH into EC2 instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Modify for production (e.g., ["192.168.1.0/24"])
}

# --- User Data Script --- #
variable "user_data" {
  description = "Base64-encoded user data script for initial configuration (e.g., installing applications)"
  type        = string
}