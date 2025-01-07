# --- AWS Region Configuration --- #
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
}

variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS account ID for permissions and policies"
  type        = string
}

# --- Environment Label --- #
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
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

# --- KMS Configuration --- #

# List of additional AWS principals that require access to the KMS key
# Useful for allowing specific IAM roles or services access to the key, expanding beyond the root account and logs service.
variable "additional_principals" {
  description = "List of additional AWS principals (e.g., services or IAM roles) that need access to the KMS key"
  type        = list(string)
  default     = [] # Default is an empty list, meaning no additional principals
}

# Allows enabling or disabling automatic key rotation for the KMS key.
variable "enable_key_rotation" {
  description = "Enable or disable automatic key rotation for the KMS key"
  type        = bool
  default     = true
}

# Enable or disable the creation of the IAM role for managing the KMS key
# Set to true to create the IAM role and its associated policy for managing the KMS key.
variable "enable_kms_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}

# --- Enable CloudWatch Monitoring --- #
# This variable controls whether CloudWatch Alarms for the KMS key usage are created.
variable "enable_key_monitoring" {
  description = "Enable or disable CloudWatch Alarms for monitoring KMS key usage."
  type        = bool
  default     = false
}

# --- Threshold for Decrypt Operations --- #
# Defines the threshold for the number of Decrypt operations that trigger a CloudWatch Alarm.
variable "key_decrypt_threshold" {
  description = "Threshold for KMS decrypt operations to trigger an alarm."
  type        = number
  default     = 100 # Example value, adjust as needed.
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

# Number of read replicas to create for the RDS instance
variable "read_replicas_count" {
  description = "Number of read replicas to create for the RDS instance"
  type        = number
}

# Toggle for enabling or disabling Performance Insights
variable "performance_insights_enabled" {
  description = "Enable or disable Performance Insights for RDS instance"
  type        = bool
}

# --- Endpoints Variables --- #

variable "enable_cloudwatch_logs_for_endpoints" {
  description = "Enable CloudWatch Logs for VPC Endpoints in stage and prod environments"
  type        = bool
  default     = false
}

# --- Log Retention Period --- #
# Defines the retention period for CloudWatch Logs.
variable "endpoints_log_retention_in_days" {
  description = "Retention period for CloudWatch Logs in days"
  type        = number
  default     = 14

  validation {
    condition     = var.endpoints_log_retention_in_days > 0
    error_message = "Log retention period must be a positive integer."
  }
}

# --- SNS Variables --- #

# List of additional SNS subscriptions (e.g., SMS, Slack)
variable "sns_subscriptions" {
  description = "List of additional SNS subscriptions (e.g., SMS, Slack)"
  type = list(object({
    protocol = string
    endpoint = string
  }))
  default = []
}

# --- ElastiCache Configuration Variables --- #

variable "redis_version" {
  description = "Redis version for the ElastiCache cluster"
  type        = string
}

variable "node_type" {
  description = "Node type for the ElastiCache cluster"
  type        = string
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard"
  type        = number
}

variable "num_node_groups" {
  description = "Number of shards (node groups)"
  type        = number
}

variable "redis_port" {
  description = "Port for the Redis cluster"
  type        = number
}

variable "snapshot_retention_limit" {
  description = "Number of backups to retain for the Redis cluster"
  type        = number
}

variable "snapshot_window" {
  description = "Time window for Redis backups (e.g., '03:00-04:00')"
  type        = string
}

# Threshold values for CloudWatch alarms related to Redis performance.
variable "redis_cpu_threshold" {
  description = "CPU utilization threshold for Redis alarms"
  type        = number
}

variable "redis_memory_threshold" {
  description = "Memory usage threshold for Redis alarms"
  type        = number
}

# Enable Freeable Memory Alarm for Redis
variable "enable_redis_low_memory_alarm" {
  description = "Enable or disable the freeable memory alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# Enable High CPU Utilization Alarm for Redis
variable "enable_redis_high_cpu_alarm" {
  description = "Enable or disable the high CPU utilization alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# Enable Low CPU Credits Alarm for Redis
variable "enable_redis_low_cpu_credits_alarm" {
  description = "Enable or disable the low CPU credits alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# --- ALB Configuration Variables --- #

# --- Deletion Protection Variable for ALB --- #
# This variable is specific to the ALB module and controls deletion protection for the ALB.
# - Default value: false (in `alb/variables.tf`).
# - Recommended: Set to true for production (prod) in `terraform.tfvars` for enhanced safety.
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the ALB (recommended for prod)"
  type        = bool
  default     = false
}

# Enable or disable HTTPS Listener
variable "enable_https_listener" {
  description = "Enable or disable the creation of the HTTPS Listener"
  type        = bool
  default     = false
}

# Enable or disable ALB access logs
variable "enable_alb_access_logs" {
  description = "Enable or disable ALB access logs"
  type        = bool
  default     = true # Logging is enabled by default
}

# Enable High Request Count Alarm
# Controls the creation of a CloudWatch Alarm for high request count on the ALB.
variable "enable_high_request_alarm" {
  description = "Enable or disable the CloudWatch alarm for high request count on the ALB."
  type        = bool
  default     = false
}

# Enable 5XX Error Alarm
# Controls the creation of a CloudWatch Alarm for HTTP 5XX errors on the ALB.
variable "enable_5xx_alarm" {
  description = "Enable or disable the CloudWatch alarm for HTTP 5XX errors on the ALB."
  type        = bool
  default     = false
}

# Toggle WAF for ALB
variable "enable_waf" {
  description = "Enable or disable WAF for ALB" # Description of the variable
  type        = bool                            # Boolean type for true/false values
  default     = false                           # Default value is false
}

# --- Enable WAF Logging --- #
# This variable controls the creation of WAF logging resources. WAF logging will be enabled only if:
# 1. `enable_waf_logging` is set to true.
# 2. Firehose (`enable_firehose`) is also enabled, as it is required for delivering logs.
# By default, WAF logging is disabled.
variable "enable_waf_logging" {
  description = "Enable or disable logging for WAF independently of WAF enablement"
  type        = bool
  default     = false
}

# Enable or disable Firehose and related resources
variable "enable_firehose" {
  description = "Enable or disable Firehose and related resources"
  type        = bool
  default     = false
}

# Enable or disable KMS IAM role and policy for ALB module
# - Set to true to create KMS-related IAM resources.
# - Set to false to skip KMS IAM resource creation.
variable "enable_kms_alb_role" {
  description = "Enable or disable KMS IAM role and policy for ALB module"
  type        = bool
  default     = false
}

# --- S3 Bucket Configuration Variables --- #

variable "buckets" {
  description = "Map of bucket names and their types (base or special)."
  type        = map(string)
}

# Versioning settings are managed in the `terraform.tfvars` file for dev environment.
variable "enable_versioning" {
  description = "Map of bucket names to enable or disable versioning."
  type        = map(bool)
  default     = {}
}

# Enable or disable the Terraform state bucket.
variable "enable_terraform_state_bucket" {
  description = "Enable or disable the Terraform state bucket"
  type        = bool
  default     = false
}

# Enable or disable the WordPress media bucket.
variable "enable_wordpress_media_bucket" {
  description = "Enable or disable the WordPress media bucket"
  type        = bool
  default     = false
}

# Enable or disable the replication bucket.
variable "enable_replication_bucket" {
  description = "Enable or disable the replication bucket"
  type        = bool
  default     = false
}

# --- Enable Replication Variable --- #
# Enable cross-region replication for S3 buckets.
variable "enable_s3_replication" {
  description = "Enable cross-region replication for S3 buckets."
  type        = bool
  default     = false
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# Lifecycle Configuration
# Number of days to retain noncurrent object versions
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent versions of objects in S3 buckets"
  type        = number
}

# --- Enable DynamoDB for State Locking --- #
# This variable controls whether the DynamoDB table for Terraform state locking is created.
# - true: Creates the DynamoDB table and associated resources for state locking.
# - false: Skips the creation of DynamoDB-related resources.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for Terraform state locking."
  type        = bool
  default     = false

  # --- Notes --- #
  # 1. When enabled, the module creates a DynamoDB table with TTL and stream configuration.
  # 2. This is required only if you are using DynamoDB-based state locking.
  # 3. If you prefer S3 Conditional Writes for state locking, set this to false.
}

# --- Enable Lambda for TTL Automation --- #
# This variable controls whether the Lambda function for TTL automation is created.
# - true: Creates the Lambda function and associated resources.
# - false: Skips the creation of Lambda-related resources.
variable "enable_lambda" {
  description = "Enable Lambda function for DynamoDB TTL automation."
  type        = bool
  default     = false

  # --- Notes --- #
  # 1. This variable must be set to true only if `enable_dynamodb = true`.
  # 2. When disabled, all Lambda-related resources (IAM role, policy, function, etc.) are skipped.
}