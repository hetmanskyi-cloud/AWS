# --- EC2 Instance Configuration Variables --- #

# Amazon Machine Image (AMI) ID used for EC2 instances.
# In stage/prod, this value is dynamically updated via S3.
variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID for the EC2 instances"
  type        = string
}

# EC2 instance type (e.g., t2.micro for Free Tier usage).
variable "instance_type" {
  description = "EC2 instance type (e.g., t2.micro)"
  type        = string
}

# --- Auto Scaling Configuration Variables --- #

# Minimum and maximum number of instances in the Auto Scaling Group.
variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
}

variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
}

# Threshold for scaling actions based on CPU utilization.
variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out (increasing instance count)"
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in (decreasing instance count)"
  type        = number
}

# Thresholds for monitoring network traffic (incoming and outgoing).
variable "network_in_threshold" {
  description = "Threshold for high incoming network traffic"
  type        = number
}

variable "network_out_threshold" {
  description = "Threshold for high outgoing network traffic"
  type        = number
}

# --- Storage Configuration Variables --- #

# Size and type of the root EBS volume for EC2 instances.
variable "volume_size" {
  description = "Size of the EBS volume for the root device in GiB"
  type        = number
}

variable "volume_type" {
  description = "Type of the EBS volume for the root device (e.g., gp2, gp3)"
  type        = string
}

# --- Network Configuration Variables --- #

# List of public subnet IDs for deploying EC2 instances.
variable "public_subnet_ids" {
  description = "List of public subnet IDs for deploying instances"
  type        = list(string)
}

# Security group IDs for controlling inbound and outbound traffic.
variable "security_group_id" {
  description = "Security group IDs for the EC2 instance to control traffic"
  type        = list(string)
}

# ID of the VPC where the EC2 instances are deployed.
variable "vpc_id" {
  description = "ID of the VPC for Security Group association"
  type        = string
}

# --- SSH Access Configuration --- #

# Optional SSH key name for accessing the EC2 instances.
variable "ssh_key_name" {
  description = "Name of the SSH key for EC2 access (only used if SSH is enabled)"
  type        = string
}

# Flag to enable or disable SSH access to EC2 instances.
variable "enable_ssh_access" {
  description = "Enable or disable SSH access to EC2 instances"
  type        = bool
}

# --- SSH Allowed IPs --- #
# Specifies the list of IP ranges allowed to access SSH in prod.
# Use this variable to restrict access to trusted IPs in production environments.
variable "ssh_allowed_ips" {
  description = "List of IP ranges allowed to access SSH in prod"
  type        = list(string)
  default     = [] # Empty by default; must be set in `terraform.tfvars` for prod.
}

# --- Variables for Database Configuration --- #

# RDS database configuration for WordPress.
variable "db_host" {
  description = "The RDS database host for WordPress configuration"
  type        = string
}

variable "db_endpoint" {
  description = "The RDS database endpoint for other configurations"
  type        = string
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

# PHP configuration for WordPress setup.
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

variable "php_fpm_service" {
  description = "PHP-FPM service name for WordPress configuration"
  type        = string
}

# --- S3 Variables --- #

# S3 buckets for AMI, WordPress media, and scripts.
variable "ami_bucket_arn" {
  description = "The ARN of the S3 bucket used for storing golden AMI images"
  type        = string
}

variable "ami_bucket_name" {
  description = "The name of the S3 bucket containing metadata for the latest AMI"
  type        = string
}

variable "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress media (not available in dev)"
  type        = string
  default     = null
}

variable "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress scripts"
  type        = string
}

# --- Scripts Bucket Name --- #
# Specifies the name of the S3 bucket used for storing deployment scripts (e.g., deploy_wordpress.sh).
# This bucket is required in stage and prod environments where deployment scripts are not stored locally.
variable "scripts_bucket_name" {
  description = "The name of the S3 bucket containing deployment scripts for EC2 instances"
  type        = string
}

# --- SNS Variables --- #

# ARN of the SNS Topic for CloudWatch alarms.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# --- Redis Variables --- #

# Redis endpoint and port for WordPress caching.
variable "redis_endpoint" {
  description = "Redis endpoint (default: localhost)"
  type        = string
}

variable "redis_port" {
  description = "Redis port (default: 6379)"
  type        = number
}

# --- ALB Variables --- #

# ALB Security Group and Target Group.
variable "alb_sg_id" {
  description = "Security Group ID for the ALB to allow traffic"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the target group for ALB"
  type        = string
}

# --- General Configuration Variables --- #

# Naming prefix for resources and environment label.
variable "name_prefix" {
  description = "Prefix for naming resources for easier organization"
  type        = string
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# User data script for configuring the EC2 instance at launch.
variable "user_data" {
  description = "Base64-encoded user data script for initial configuration (e.g., installing applications)"
  type        = string
  default     = null
}

# --- Notes --- #
# 1. Variables are grouped by functionality (e.g., EC2, S3, Auto Scaling) for clarity.
# 2. Environment (`environment`):
#    - `dev`: Used for development and testing with simplified configurations.
#    - `stage`: Pre-production environment for validation.
#    - `prod`: Production environment with full scaling and security enabled.
# 3. Conditional logic ensures the module adapts to different environments (`dev`, `stage`, `prod`).
# 4. Sensitive variables (e.g., `db_password`) are marked for secure handling in Terraform.
# 5. `scripts_bucket_name` and `ami_bucket_name`:
#    - Required in `stage` and `prod` for fetching deployment scripts and AMI metadata from S3.
#    - Ensure the S3 bucket names are valid and accessible before deployment.
# 6. Best Practices:
#    - Regularly review and validate variable inputs, especially for sensitive or critical configurations.
#    - Use environment-specific `terraform.tfvars` files to manage variable values efficiently.