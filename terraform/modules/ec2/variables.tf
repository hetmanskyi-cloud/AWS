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

# Threshold for high incoming network traffic. Triggers an alarm when exceeded. 
variable "network_in_threshold" {
  description = "Threshold for high incoming network traffic"
  type        = number
}

# Threshold for high outgoing network traffic. Triggers an alarm when exceeded. 
variable "network_out_threshold" {
  description = "Threshold for high outgoing network traffic"
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
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Security Group Variables --- #

# VPC ID where the EC2 instances are deployed
variable "vpc_id" {
  description = "ID of the VPC for Security Group association"
  type        = string
}

# --- SSH Access Configuration --- #

# Enable or disable SSH access to EC2 instances (recommended to disable in production)
variable "enable_ssh_access" {
  description = "Enable or disable SSH access to EC2 instances"
  type        = bool
}

# --- Variables for Database Configuration --- #

# Database host for WordPress configuration
# This is the primary RDS host used for establishing connections from the WordPress application.
variable "db_host" {
  description = "The RDS database host for WordPress configuration"
  type        = string
}

# Full database endpoint for potential other configurations
# This variable holds the full endpoint of the RDS database. Use it for any scenarios where the endpoint is required instead of just the host.
variable "db_endpoint" {
  description = "The RDS database endpoint for other configurations"
  type        = string
}

# Name of the RDS database
# This variable specifies the name of the initial database created during RDS setup.
variable "db_name" {
  description = "Name of the RDS database"
  type        = string
}

# Master username for RDS
# The username used for administrative access to the RDS database.
variable "db_username" {
  description = "Master username for RDS"
  type        = string
}

# Master password for RDS
# A sensitive variable that stores the master password for accessing the RDS database.
variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

# PHP version for WordPress installation
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

# PHP-FPM service name for WordPress configuration
variable "php_fpm_service" {
  type = string
}

# --- S3 Variables --- #

variable "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress media"
  type        = string
}

variable "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress scripts"
  type        = string
}

variable "ami_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing golden AMI images"
  type        = string
}

# --- SNS Variables --- #

# ARN of the SNS Topic for CloudWatch alarms
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# --- Redis Variables --- #

variable "redis_port" {
  description = "Redis port (default: 6379)"
  type        = number
}

variable "redis_endpoint" {
  description = "Redis endpoint (default: localhost)"
  type        = string
}

# --- ALB Variables --- #

variable "alb_sg_id" {
  description = "Security Group ID for the ALB to allow traffic"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the target group for ALB"
  type        = string
}
