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

variable "username" {
  description = "Master username for RDS"
  type        = string
}

variable "password" {
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

# --- Security Group Variables --- #

variable "rds_security_group_id" {
  description = "ID of the Security Group for RDS instances"
  type        = list(string)
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