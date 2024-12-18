# --- RDS Module Variables --- #

# --- AWS Region Configuration --- #
# Specifies the AWS region where RDS resources will be created.
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
}

# --- AWS Account ID --- #
# Used for permissions and resource identification.
variable "aws_account_id" {
  description = "AWS account ID for permissions and policies"
  type        = string
}

# --- Naming and Environment Variables --- #
# General variables for consistent naming and environment configuration.
variable "name_prefix" {
  description = "Prefix for resource names"
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

# --- RDS Instance Configuration Variables --- #
# Configuration options for the RDS database instance.
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

# --- Backup and Retention Configuration --- #
# Configures backup retention and time windows for automated backups.
variable "backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
}

variable "backup_window" {
  description = "Preferred window for automated RDS backups (e.g., '02:00-03:00')"
  type        = string
}

# --- Performance Insights --- #
# Toggle for enabling or disabling Performance Insights on RDS.
variable "performance_insights_enabled" {
  description = "Enable or disable Performance Insights for RDS instance"
  type        = bool
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
# Specifies networking details such as VPC ID and subnet IDs.
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
# Manages security group configurations for RDS access.
variable "rds_security_group_id" {
  description = "ID of the Security Group for RDS instances"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security Group ID for EC2 instances"
  type        = string
}

# --- KMS Key ARN for Encryption --- #
variable "kms_key_arn" {
  description = "The ARN of the KMS key for RDS encryption"
  type        = string
}

# --- Enhanced Monitoring Configuration --- #
variable "enable_monitoring" {
  description = "Enable RDS enhanced monitoring if set to true"
  type        = bool
}

# --- CloudWatch Monitoring Variables --- #
# Threshold values for CloudWatch alarms.
variable "rds_cpu_threshold_high" {
  description = "Threshold for high CPU utilization on RDS"
  type        = number
}

variable "rds_storage_threshold" {
  description = "Threshold for low free storage space on RDS (in bytes)"
  type        = number
}

variable "rds_connections_threshold" {
  description = "Threshold for high number of database connections on RDS"
  type        = number
}

# --- SNS Topic for Alarms --- #
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}

# --- Read Replica Configuration --- #
variable "read_replicas_count" {
  description = "Number of read replicas for the RDS instance"
  type        = number
}

variable "db_instance_identifier" {
  description = "The identifier of the primary RDS database instance."
  type        = string
}

# --- Notes --- #
# 1. Variables are organized into logical sections for naming, environment, networking, and monitoring.
# 2. RDS instance configuration allows for customization of storage, performance insights, and backups.
# 3. Monitoring thresholds for CPU, storage, and connections ensure proactive alerting.
# 4. Read replica count and encryption settings are customizable to meet high availability requirements.
# 5. Sensitive variables like 'db_password' are marked sensitive to avoid accidental exposure.