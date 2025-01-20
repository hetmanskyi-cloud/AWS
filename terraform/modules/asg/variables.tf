# --- ASG Variables --- #
# This file contains all the configurable variables for the ASG module.

# --- General Configuration --- #
# Naming prefix and environment settings for better organization.
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

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting S3 bucket objects"
  type        = string
}

# --- ASG Instance Configuration --- #
# Parameters related to instance type, AMI ID, and SSH settings.

variable "instance_type" {
  description = "ASG instance type (e.g., t2.micro)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instance image"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key for ASG access"
  type        = string
}

variable "enable_asg_ssh_access" {
  description = "Allow SSH access to ASG instances"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "List of allowed CIDR blocks for SSH access to ASG instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for development, restrict for production
}

variable "enable_public_ip" {
  description = "Enable public IP for ASG instances"
  type        = bool
  default     = false
}

# --- Auto Scaling Configuration --- #
# Variables controlling the scaling behavior of the ASG.

variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
}

variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group; null for dynamic adjustment"
  type        = number
  default     = null
}

variable "enable_scaling_policies" {
  description = "Enable or disable scaling policies for the ASG"
  type        = bool
  default     = true
}

# --- Scaling Policy Thresholds --- #
# Parameters related to CPU and network usage for scaling decisions.

variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out (increasing instance count)"
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in (decreasing instance count)"
  type        = number
}

variable "network_in_threshold" {
  description = "Threshold for high incoming network traffic"
  type        = number
}

variable "network_out_threshold" {
  description = "Threshold for high outgoing network traffic"
  type        = number
}

# --- Monitoring & Alarm Configuration --- #
# Enables or disables various monitoring alarms for ASG performance.

variable "enable_scale_out_alarm" {
  description = "Enable or disable the Scale-Out Alarm for ASG"
  type        = bool
  default     = true
}

variable "enable_scale_in_alarm" {
  description = "Enable or disable the Scale-In Alarm for ASG"
  type        = bool
  default     = true
}

variable "enable_asg_status_check_alarm" {
  description = "Enable or disable the ASG Status Check Alarm"
  type        = bool
  default     = false
}

variable "enable_high_network_in_alarm" {
  description = "Enable or disable the High Network-In Alarm for ASG"
  type        = bool
  default     = false
}

variable "enable_high_network_out_alarm" {
  description = "Enable or disable the High Network-Out Alarm for ASG"
  type        = bool
  default     = false
}

# --- Storage Configuration --- #
# EBS volume settings for the ASG instances.

variable "volume_size" {
  description = "Size of the EBS volume for the root device in GiB"
  type        = number
}

variable "volume_type" {
  description = "Type of the EBS volume for the root device (e.g., gp2, gp3)"
  type        = string
}

variable "enable_ebs_encryption" {
  description = "Enable encryption for ASG EC2 instance root volumes"
  type        = bool
  default     = false
}

# --- Network Configuration --- #
# Subnet and VPC details for deploying ASG instances.

variable "vpc_id" {
  description = "ID of the VPC for Security Group association"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for deploying instances"
  type        = list(string)
}

# --- Database Configuration --- #
# Variables related to RDS database integration with the ASG.

variable "db_host" {
  description = "The RDS database host for WordPress configuration"
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

variable "db_endpoint" {
  description = "The RDS database endpoint for other configurations"
  type        = string
}

# --- PHP configuration for WordPress setup --- #
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

variable "php_fpm_service" {
  description = "PHP-FPM service name for WordPress configuration"
  type        = string
}

# --- S3 Configuration --- #
# S3 bucket configuration for storing media and scripts.

variable "enable_wordpress_media_bucket" {
  description = "Enable or disable access to the WordPress Media S3 bucket"
  type        = bool
}

variable "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress media"
  type        = string
  default     = null
}

variable "wordpress_media_bucket_name" {
  description = "The name of the S3 bucket for WordPress media"
  type        = string
  default     = null
}

variable "scripts_bucket_name" {
  description = "Name of the S3 bucket containing deployment scripts"
  type        = string
}

variable "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket for deployment scripts"
  type        = string
}

# --- ALB Configuration --- #
# ALB target group and security group settings for ASG.

variable "alb_security_group_id" {
  description = "Security Group ID for the ALB to allow traffic"
  type        = string
}

variable "wordpress_tg_arn" {
  description = "ARN of the Target Group for WordPress. Required when ALB health checks are enabled."
  type        = string

  validation {
    condition     = length(var.wordpress_tg_arn) > 0
    error_message = "The ALB Target Group ARN must be specified when health_check_type is set to ELB."
  }
}

variable "enable_https_listener" {
  description = "Enable or disable HTTPS listener from ALB module"
  type        = bool
}

# --- SNS Configuration --- #

# Variables related to AWS SNS for alarm notifications.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# --- Security Groups --- #

# RDS Security Group ID
variable "rds_security_group_id" {
  description = "Security Group ID for the RDS instance to allow traffic"
  type        = string
}

# ElastiCache Security Group ID
variable "redis_security_group_id" {
  description = "Security Group ID for ElastiCache instance to allow traffic"
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

# --- Additional Variables --- #

variable "enable_s3_script" {
  description = "Flag to determine if the WordPress deployment script should be fetched from S3"
  type        = bool
  default     = false
}

variable "enable_data_source" {
  description = "Enable or disable the data source for fetching ASG instance details"
  type        = bool
  default     = false
}

# --- Notes --- #
# 1. **Variable Grouping:**
#    - Variables are grouped by functionality to simplify management.
#
# 2. **Sensitive Data Handling:**
#    - The `db_password` variable is marked as sensitive to avoid exposing secrets.
#
# 3. **Best Practices:**
#    - Use different values for `ssh_allowed_cidr` in production to restrict access.
#    - Ensure proper values are set for autoscaling thresholds based on traffic patterns.