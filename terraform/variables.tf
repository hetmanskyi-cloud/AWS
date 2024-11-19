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

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
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

# Actions to perform when an alarm is triggered.
variable "alarm_actions" {
  description = "Actions to perform when an alarm is triggered"
  type        = list(string)
  default     = []
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
  default     = ""
}

# --- SSH Access Configuration --- #
# Enable or disable SSH access to EC2 instances (recommended to disable in production)
variable "enable_ssh_access" {
  description = "Enable or disable SSH access to EC2 instances"
  type        = bool
}

# --- RDS Configuration --- #

# Storage size in GB for the RDS instance
variable "allocated_storage" {
  description = "Storage size in GB for the RDS instance"
  type        = number
}

# Instance class for RDS
variable "instance_class" {
  description = "Instance class for RDS"
  type        = string
}

# Database engine for the RDS instance (e.g., 'mysql', 'postgres')
variable "engine" {
  description = "Database engine for the RDS instance (e.g., 'mysql', 'postgres')"
  type        = string
}

# Database engine version
variable "engine_version" {
  description = "Database engine version"
  type        = string
}

# Master username for RDS
variable "db_username" {
  description = "Master username for RDS"
  type        = string
}

# Master password for RDS
variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

# Initial database name
variable "db_name" {
  description = "Initial database name"
  type        = string
}

# Database port for RDS (e.g., 3306 for MySQL)
variable "db_port" {
  description = "Database port for RDS (e.g., 3306 for MySQL)"
  type        = number
}

# Number of days to retain RDS backups
variable "backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
}

# Preferred window for automated RDS backups
variable "backup_window" {
  description = "Preferred window for automated RDS backups"
  type        = string
}

# Enable Multi-AZ deployment for RDS high availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS high availability"
  type        = bool
}

# Enable or disable deletion protection for RDS instance
variable "enable_deletion_protection" {
  description = "Enable or disable deletion protection for RDS instance"
  type        = bool
}

# Skip final snapshot when deleting the RDS instance
variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting the RDS instance"
  type        = bool
  default     = false
}

# Enable or disable enhanced monitoring for RDS instances
variable "enable_monitoring" {
  description = "Enable or disable enhanced monitoring for RDS instances"
  type        = bool
  default     = false
}

# PHP version for WordPress installation
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

# --- RDS Monitoring Variables --- #

# Threshold for CPU utilization alarm
variable "rds_cpu_threshold" {
  description = "Threshold for high CPU utilization on RDS"
  type        = number
}

# Threshold for free storage space alarm
variable "rds_storage_threshold" {
  description = "Threshold for low free storage space on RDS (in bytes)"
  type        = number
}

# Threshold for high database connections alarm
variable "rds_connections_threshold" {
  description = "Threshold for high number of database connections on RDS"
  type        = number
}

# --- S3 Variables --- #

# Lifecycle Configuration
# Number of days to retain noncurrent object versions
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent versions of objects in S3 buckets"
  type        = number
}

# --- SNS Variables --- #

# List of email addresses for SNS subscriptions
variable "sns_email_subscribers" {
  description = "List of email addresses to receive SNS notifications"
  type        = list(string)
  default     = []
}

# List of additional SNS subscriptions (e.g., SMS, Slack)
variable "sns_subscriptions" {
  description = "List of additional SNS subscriptions (e.g., SMS, Slack)"
  type = list(object({
    protocol = string
    endpoint = string
  }))
  default = []
}

