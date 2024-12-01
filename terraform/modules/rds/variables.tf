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

# --- Naming and Environment Variables --- #

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, prod)"
  type        = string
}

# --- RDS Instance Configuration Variables --- #

variable "allocated_storage" {
  description = "Storage size in GB for the RDS instance"
  type        = number
}

variable "instance_class" {
  description = "Instance class for RDS"
  type        = string
}

variable "engine" {
  description = "Database engine for the RDS instance (e.g., 'mysql', 'postgres')"
  type        = string
}

variable "engine_version" {
  description = "Database engine version (e.g., '8.0' for MySQL)"
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

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "db_port" {
  description = "Database port for RDS (e.g., 3306 for MySQL)"
  type        = number
  default     = 3306
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS high availability"
  type        = bool
}

# Toggle for enabling or disabling Performance Insights
variable "performance_insights_enabled" {
  description = "Enable or disable Performance Insights for RDS instance"
  type        = bool
  default     = false
}

# --- Backup and Retention Configuration --- #

variable "backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
}

variable "backup_window" {
  description = "Preferred window for automated RDS backups (e.g., '02:00-03:00')"
  type        = string
}

# --- Deletion Protection and Final Snapshot --- #

variable "deletion_protection" {
  description = "Enable or disable deletion protection for RDS instance"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting the RDS instance"
  type        = bool
  default     = false
}

# --- Networking Variables --- #

variable "vpc_id" {
  description = "The ID of the VPC where the RDS instance is hosted"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS deployment"
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

# --- Security Group Variables --- #

variable "rds_security_group_id" {
  description = "ID of the Security Group for RDS instances"
  type        = list(string)
}

# Variable to pass EC2 Security Group ID
variable "ec2_security_group_id" {
  description = "Security Group ID for EC2 instances"
  type        = string
}

# --- KMS Key ARN for Encryption --- #

variable "kms_key_arn" {
  description = "The ARN of the KMS key for RDS encryption"
  type        = string
}

# Enable or disable enhanced monitoring for RDS
variable "enable_monitoring" {
  description = "Enable RDS enhanced monitoring if set to true"
  type        = bool
}

# --- RDS Monitoring Variables --- #

# Threshold for CPU utilization alarm
variable "rds_cpu_threshold_high" {
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

# --- SNS Variables --- #

# ARN of the SNS Topic for CloudWatch alarms
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# --- Lambda Variables --- #

# Number of read replicas
variable "read_replicas_count" {
  description = "Number of read replicas for the RDS instance"
  type        = number
}

variable "db_instance_identifier" {
  description = "The identifier of the primary RDS database instance."
  type        = string
}
