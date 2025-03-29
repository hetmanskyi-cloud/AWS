# --- AWS Region Configuration --- #
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
}

# Region where the replication bucket will be created, typically different from the primary region.
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

# --- VPC Module Configuration --- #

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

# --- CloudWatch Flow Log Retention --- #

variable "flow_logs_retention_in_days" {
  description = "Retention period in days for CloudWatch logs"
  type        = number
}

# --- KMS Module Configuration --- #

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

# --- ASG Module Configuration --- #

# Settings for instance, AMI, and key
variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID for the ASG instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t2.micro)"
  type        = string
}

variable "enable_s3_script" {
  description = "Flag to determine if the WordPress deployment script should be fetched from S3"
  type        = bool
  default     = false
}

variable "s3_scripts" {
  description = "Map of files to be uploaded to the scripts bucket when enable_s3_script is true"
  type        = map(string)
  default     = {}
}

variable "enable_asg_ssh_access" {
  description = "Allow SSH access to ASG instances"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of the SSH key for ASG access"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "List of allowed CIDR blocks for SSH access to ASG instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for development, restrict for production
}

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

variable "enable_target_tracking" {
  description = "Enable target tracking scaling policy (recommended)"
  type        = bool
  default     = true
}

variable "enable_data_source" {
  description = "Enable or disable the data source for fetching ASG instance details"
  type        = bool
  default     = false
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

# Enable or disable the Scale-Out Alarm
variable "enable_scale_out_alarm" {
  description = "Enable or disable the Scale-Out Alarm for ASG"
  type        = bool
  default     = true
}

# Enable or disable the Scale-In Alarm
variable "enable_scale_in_alarm" {
  description = "Enable or disable the Scale-In Alarm for ASG"
  type        = bool
  default     = true
}

# Enable or disable the ASG Status Check Alarm
variable "enable_asg_status_check_alarm" {
  description = "Enable or disable the ASG Status Check Alarm"
  type        = bool
  default     = false
}

# Enable or disable the High Network-In Alarm
variable "enable_high_network_in_alarm" {
  description = "Enable or disable the High Network-In Alarm for ASG"
  type        = bool
  default     = false
}

# Enable or disable the High Network-Out Alarm
variable "enable_high_network_out_alarm" {
  description = "Enable or disable the High Network-Out Alarm for ASG"
  type        = bool
  default     = false
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

variable "enable_ebs_encryption" {
  description = "Enable encryption for ASG EC2 instance root volumes"
  type        = bool
  default     = false
}

# --- WordPress Configuration --- #

variable "wp_title" {
  description = "Title of the WordPress site"
  type        = string
  sensitive   = true
}

variable "wp_admin_email" {
  description = "Admin email for WordPress"
  type        = string
  sensitive   = true
}

variable "wp_admin_password" {
  description = "Admin password for WordPress (stored securely)"
  type        = string
  sensitive   = true
}

variable "wordpress_secret_name" {
  description = "The name of the Secrets Manager secret for WordPress credentials"
  type        = string
}

variable "healthcheck_version" {
  type        = string
  default     = "1.0"
  description = "Determines which healthcheck file to use (1.0 or 2.0)."
}

# --- WordPress Database Configuration --- #
variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Username for the WordPress database"
  type        = string
}

variable "db_password" {
  description = "Password for the WordPress database"
  type        = string
  sensitive   = true
}

# --- WordPress Admin Configuration --- #
variable "wp_admin_user" {
  description = "WordPress admin username"
  type        = string
  default     = "admin"
}

# --- RDS Module Configuration --- #

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
variable "rds_deletion_protection" {
  description = "Enable or disable deletion protection for RDS instance"
  type        = bool
}

# Skip final snapshot when deleting the RDS instance
variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting the RDS instance"
  type        = bool
}

# Enable or disable enhanced monitoring for RDS instances
variable "enable_rds_monitoring" {
  description = "Enable or disable enhanced monitoring for RDS instances"
  type        = bool
  default     = false
}

# PHP version for WordPress installation
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

# RDS Log Retention Period
variable "rds_log_retention_days" {
  description = "Number of days to retain RDS logs in CloudWatch"
  type        = number
  default     = 30
}

# --- RDS Module Variables --- #

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

# Enable or disable specific CloudWatch Alarms
variable "enable_low_storage_alarm" {
  description = "Enable the CloudWatch Alarm for low storage on RDS"
  type        = bool
  default     = true
}

variable "enable_high_cpu_alarm" {
  description = "Enable the CloudWatch Alarm for high CPU utilization on RDS"
  type        = bool
  default     = true
}

variable "enable_high_connections_alarm" {
  description = "Enable the CloudWatch Alarm for high database connections on RDS"
  type        = bool
  default     = true
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

# --- S3 Module Variables --- #

variable "default_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false)
    replication           = optional(bool, false)
    server_access_logging = optional(bool, false)
    region                = optional(string, null) # Optional: region (defaults to provider)    
  }))
  description = "Config for default AWS region buckets." # Description: Default region buckets config
  default     = {}
}

variable "replication_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false) # Versioning MUST be enabled for replication destinations    
    server_access_logging = optional(bool, false)
    region                = string # AWS region for the replication bucket (REQUIRED)
  }))
  description = "Configuration for S3 buckets specifically in the replication AWS region."
  default     = {}
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# Allowed origins
variable "allowed_origins" {
  description = "List of allowed origins for S3 bucket CORS"
  type        = list(string)
  default     = ["https://example.com"]
}

# Lifecycle Configuration
# Number of days to retain noncurrent object versions
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent versions of objects in S3 buckets"
  type        = number
}

# --- Enable DynamoDB for State Locking --- #
# Controls the creation of the DynamoDB table for state locking.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for state locking."
  type        = bool
  default     = false

  # Ensures DynamoDB is only enabled when S3 bucket are active.
  validation {
    condition     = var.enable_dynamodb ? contains(keys(var.default_region_buckets), "terraform_state") && var.default_region_buckets["terraform_state"].enabled : true
    error_message = "enable_dynamodb requires `terraform_state` bucket to be enabled."
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

# --- ElastiCache Module Variables --- #

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
  validation {
    condition     = var.replicas_per_node_group >= 0
    error_message = "replicas_per_node_group must be a non-negative integer."
  }
}

variable "num_node_groups" {
  description = "Number of shards (node groups)"
  type        = number
  validation {
    condition     = var.num_node_groups > 0
    error_message = "num_node_groups must be greater than zero."
  }
}

variable "enable_failover" {
  description = "Enable or disable automatic failover for Redis replication group"
  type        = bool
  default     = false
  validation {
    condition     = var.enable_failover ? var.replicas_per_node_group > 0 : true
    error_message = "Automatic failover can only be enabled if replicas_per_node_group > 0."
  }
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

# --- Enable Replication Bytes Used Alarm --- #
# Controls whether the CloudWatch alarm for ReplicationBytesUsed is created.
# Relevant only when replicas are enabled (replicas_per_node_group > 0).
variable "enable_redis_replication_bytes_alarm" {
  description = "Enable or disable the ReplicationBytesUsed alarm. Relevant only for configurations with replicas."
  type        = bool
  default     = false

  validation {
    condition     = !(var.enable_redis_replication_bytes_alarm && var.replicas_per_node_group == 0)
    error_message = "ReplicationBytesUsed alarm can only be enabled if replicas_per_node_group > 0."
  }
}

variable "redis_cpu_credits_threshold" {
  description = "Threshold for Redis CPU credits alarm. Relevant for burstable instances."
  type        = number
  default     = 5
}

# --- Threshold for Replication Bytes Used Alarm --- #
# Threshold for triggering the replication bytes used alarm.
variable "redis_replication_bytes_threshold" {
  description = "Threshold (in bytes) for replication bytes used alarm in Redis."
  type        = number
  default     = 50000000 # Example threshold: 50 MB
}

# Enable Low CPU Credits Alarm for Redis
variable "enable_redis_low_cpu_credits_alarm" {
  description = "Enable or disable the low CPU credits alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# --- ALB Module Variables --- #

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

# --- Enable Target Response Time Alarm --- #
# Controls the creation of a CloudWatch Alarm for Target Response Time.
# true: The metric is created. false: The metric is not created.
variable "enable_target_response_time_alarm" {
  description = "Enable or disable the CloudWatch alarm for Target Response Time."
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

# --- CloudTrail Variables --- #
variable "cloudtrail_logs_retention_in_days" {
  description = "Retention period (in days) for CloudTrail logs in CloudWatch"
  type        = number
  default     = 30
}

# --- Interface Endpoints Module Variables --- #

variable "enable_interface_endpoints" {
  description = "Enable or disable Interface VPC Endpoints (SSM, CloudWatch, KMS, etc.)"
  type        = bool
  default     = false
}