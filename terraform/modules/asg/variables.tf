# --- ASG Variables --- #
# This file contains all the configurable variables for the ASG module.

# --- General Configuration --- #
# Naming prefix and environment settings for better organization.

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

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
  default     = ["0.0.0.0/0"] # Open for development. STRICTLY RESTRICT in production (e.g., VPN CIDR).
}

# --- Auto Scaling Configuration --- #
# Variables controlling the scaling behavior of the ASG.

variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number

  validation {
    condition     = var.autoscaling_min >= 0
    error_message = "The minimum number of instances must be greater than or equal to 0."
  }
}

variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number

  validation {
    condition     = var.autoscaling_max >= 0
    error_message = "The maximum number of instances must be greater than or equal to 0."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group; null for dynamic adjustment"
  type        = number
  default     = null

  validation {
    condition     = var.desired_capacity == null ? true : var.desired_capacity >= 0
    error_message = "The desired capacity must be greater than or equal to 0 or null for dynamic adjustment."
  }
}

variable "enable_scaling_policies" {
  description = "Enable or disable scaling policies for the ASG"
  type        = bool
  default     = true
}

variable "enable_target_tracking" {
  description = "Enable target tracking scaling policy (recommended)"
  type        = bool
  default     = true
}

# --- Scaling Policy Thresholds --- #
# Parameters related to CPU and network usage for scaling decisions.

variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold (percentage) for scaling out (increasing instance count)"
  type        = number

  validation {
    condition     = var.scale_out_cpu_threshold > 0 && var.scale_out_cpu_threshold <= 100
    error_message = "The CPU threshold must be between 1 and 100 percent."
  }
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold (percentage) for scaling in (decreasing instance count)"
  type        = number

  validation {
    condition     = var.scale_in_cpu_threshold > 0 && var.scale_in_cpu_threshold <= 100
    error_message = "The CPU threshold must be between 1 and 100 percent."
  }
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
  description = "Enable encryption for ASG EC2 instance root volumes (Recommended: true in production)"
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

variable "db_endpoint" {
  description = "The RDS database endpoint for other configurations"
  type        = string
}

# --- WordPress Database Configuration --- #
variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
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

# --- WordPress Configuration --- #

variable "wp_title" {
  description = "Title of the WordPress site"
  type        = string
  sensitive   = true # Could contain branding or sensitive info
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "wordpress_secrets_name" {
  description = "The name of the WordPress Secrets Manager secret"
  type        = string
}

variable "wordpress_secrets_arn" {
  description = "The ARN of the WordPress Secrets Manager secret"
  type        = string
}

# --- S3 Configuration --- #
# S3 bucket configuration for storing media and scripts.

variable "default_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, false)
    replication = optional(bool, false)
    logging     = optional(bool, false)
    region      = optional(string, null) # Optional region, defaults to provider region if not set
  }))
  description = "Configuration for S3 buckets in the default AWS region."
  default     = {}
}

variable "replication_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, true)  # Versioning MUST be enabled for replication destinations
    replication = optional(bool, false) # Replication is not applicable for replication buckets themselves
    logging     = optional(bool, false)
    region      = string # AWS region for the replication bucket (REQUIRED)
  }))
  description = "Configuration for S3 buckets specifically in the replication AWS region."
  default     = {}
}

variable "wordpress_media_bucket_arn" {
  description = "The ARN of the S3 bucket for WordPress media"
  type        = string
  default     = ""
}

variable "wordpress_media_bucket_name" {
  description = "The name of the S3 bucket for WordPress media"
  type        = string
  default     = ""
}

variable "scripts_bucket_arn" {
  description = "The ARN of the S3 bucket for deployment scripts"
  type        = string
  default     = ""
}

variable "scripts_bucket_name" {
  description = "Name of the S3 bucket containing deployment scripts"
  type        = string
  default     = ""
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

# --- VPC Endpoint Security Group ID --- #
# Used to allow ASG instances to communicate with VPC Endpoints
variable "vpc_endpoint_security_group_id" {
  description = "Security Group ID for VPC Endpoints"
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

variable "redis_auth_secret_arn" {
  description = "ARN of the Redis AUTH secret in AWS Secrets Manager"
  type        = string
  default     = ""
}

variable "redis_auth_secret_name" {
  description = "Name of the Redis AUTH secret in AWS Secrets Manager"
  type        = string
  default     = ""
}

# --- Additional Variables --- #

variable "enable_data_source" {
  description = "Enable or disable the data source for fetching ASG instance details"
  type        = bool
  default     = false
}

# --- Interface VPC Endpoints Toggle --- #
# Controls whether Interface VPC Endpoints (SSM, CloudWatch, KMS, etc.) are created.
variable "enable_interface_endpoints" {
  description = "Enable or disable Interface VPC Endpoints (SSM, CloudWatch, KMS, etc.)"
  type        = bool
  default     = false
}

# --- Notes --- #
# 1. **Variable Grouping:**
#    - Variables are organized by functionality (e.g., ASG, ALB, Redis, S3, scaling, monitoring).
#    - Logical grouping simplifies navigation and improves maintainability.

# 2. **Sensitive Data Handling:**
#    - Secrets such as WordPress DB credentials and Redis AUTH tokens should be stored in AWS Secrets Manager.
#    - Use `wordpress_secrets_name` and `redis_auth_secret_name` to retrieve them during deployment.
#    - Sensitive fields are marked accordingly to prevent Terraform from displaying them in logs or state files.

# 3. **Validation Rules:**
#    - Autoscaling values must be non-negative (`min`, `max`, `desired_capacity`).
#    - CPU thresholds must be between 1 and 100 percent.
#    - Subnet, VPC, SG, and other IDs are assumed to be passed from validated upstream modules.

# 4. **Best Practices:**
#    - Use restrictive `ssh_allowed_cidr` values in production (e.g., corporate VPN only).
#    - Set `enable_asg_ssh_access = false` in production; prefer Session Manager (SSM).
#    - Enable EBS volume encryption using KMS (`enable_ebs_encryption = true`).
#    - Choose appropriate volume types based on workload (e.g., gp3 for IOPS/cost balance).

# 5. **Production Recommendations:**
#    - Place ASG instances in public subnets **only when behind an ALB** and when NAT is not used.
#    - Use `enable_interface_endpoints = true` when instances need private access to AWS services (e.g., SSM).
#    - Always upload `deploy_wordpress.sh`, `wp-config-template.php`, and `healthcheck.php` to the S3 scripts bucket before deployment.
#    - Encrypted S3 buckets (referenced via `wordpress_media_bucket_arn` and `scripts_bucket_arn`) are recommended for storing all deployment-related artifacts.
#    - The module assumes that deployment scripts are always loaded from S3 — no fallback to local scripts is supported.