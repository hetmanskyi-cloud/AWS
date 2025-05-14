# --- ElastiCache Module Variables --- #

# --- Resource Naming and Environment --- #
# Variables for consistent resource naming and environment identification
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  validation {
    condition     = length(var.name_prefix) > 0
    error_message = "The name_prefix variable cannot be empty."
  }
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# Tags for resource identification and management
variable "tags" {
  description = "Component-level tags used for identifying resource ownership"
  type        = map(string)
}

# --- Network Configuration --- #
# Variables for VPC and subnets
variable "vpc_id" {
  description = "VPC ID"
  type        = string
  validation {
    condition     = can(regex("^vpc-[a-f0-9]{8,17}$", var.vpc_id))
    error_message = "The VPC ID must be a valid AWS VPC ID."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Redis"
  type        = list(string)
  validation {
    condition = alltrue([
      for id in var.private_subnet_ids : can(regex("^subnet-[a-f0-9]{8,17}$", id))
    ])
    error_message = "All subnet IDs must be valid AWS subnet IDs."
  }
}

# --- Security Configuration --- #
# Security-related settings including encryption and access control

variable "asg_security_group_id" {
  description = "Security Group ID of ASG instances that require access to Redis"
  type        = string
}

variable "redis_security_group_id" {
  description = "Security Group ID for ElastiCache Redis. Used for cross-module integration."
  type        = string
  default     = null
}

variable "redis_auth_secret_name" {
  description = "Name of the Secrets Manager secret containing the Redis AUTH token"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Redis data at rest"
  type        = string
  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "The kms_key_arn variable cannot be empty. Please provide a valid ARN for encrypting data at rest."
  }
}

# --- Redis Core Configuration --- #
# Essential settings for Redis cluster setup
variable "redis_version" {
  description = "Redis version (e.g., '7.1')"
  type        = string
  validation {
    condition     = can(regex("^[0-9]\\.[0-9]$", var.redis_version))
    error_message = "Redis version must be in format 'X.Y' (e.g., '7.1')."
  }
}

variable "node_type" {
  description = "Node type for Redis (e.g., 'cache.t2.micro')"
  type        = string
}

# --- Cluster Architecture --- #
# Settings that define the Redis cluster structure and failover behavior
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
  description = "Redis port for connections (default: 6379)"
  type        = number
  default     = 6379
  validation {
    condition     = var.redis_port > 0 && var.redis_port <= 65535
    error_message = "The Redis port must be a valid TCP port number between 1 and 65535."
  }
}

# --- Backup and Recovery --- #
# Configuration for Redis snapshots and backup management
variable "snapshot_retention_limit" {
  description = "Number of snapshots to retain"
  type        = number
}

variable "snapshot_window" {
  description = "Preferred window for snapshots (e.g., '03:00-04:00')"
  type        = string
  default     = "03:00-04:00"
  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", var.snapshot_window))
    error_message = "Invalid snapshot window format. Expected format is 'HH:MM-HH:MM'."
  }
}

# --- Monitoring and Alerting --- #
# CloudWatch alarm thresholds
variable "redis_cpu_threshold" {
  description = "CPU utilization threshold for Redis alarms (percentage)"
  type        = number
  validation {
    condition     = var.redis_cpu_threshold > 0 && var.redis_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100 percent."
  }
}

variable "redis_memory_threshold" {
  description = "Memory usage threshold for Redis alarms (bytes)"
  type        = number
  validation {
    condition     = var.redis_memory_threshold > 0
    error_message = "Memory threshold must be greater than 0 bytes."
  }
}

variable "redis_cpu_credits_threshold" {
  description = "Threshold for Redis CPU credits alarm. Relevant for burstable instances."
  type        = number
  default     = 5
}

# --- Alarm Configuration --- #
# SNS topic and alarm enable flags
variable "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  type        = string
}

# Enable/disable flags for different alarms
variable "enable_redis_low_memory_alarm" {
  description = "Enable or disable the freeable memory alarm for Redis"
  type        = bool
  default     = false
}

variable "enable_redis_high_cpu_alarm" {
  description = "Enable or disable the high CPU utilization alarm for Redis"
  type        = bool
  default     = false
}

variable "enable_redis_replication_bytes_alarm" {
  description = "Enable or disable the ReplicationBytesUsed alarm. Relevant only for configurations with replicas."
  type        = bool
  default     = false
  validation {
    condition     = !(var.enable_redis_replication_bytes_alarm && var.replicas_per_node_group == 0)
    error_message = "ReplicationBytesUsed alarm can only be enabled if replicas_per_node_group > 0."
  }
}

variable "redis_replication_bytes_threshold" {
  description = "Threshold (in bytes) for replication bytes used alarm in Redis"
  type        = number
  default     = 50000000 # 50 MB
}

variable "enable_redis_low_cpu_credits_alarm" {
  description = "Enable or disable the low CPU credits alarm for Redis. Relevant only for burstable instance types."
  type        = bool
  default     = false
  validation {
    condition     = !(var.enable_redis_low_cpu_credits_alarm && !can(regex("^cache\\.(t2|t3|t4g)\\.", var.node_type)))
    error_message = "CPU credits alarm can only be enabled for burstable instance types (e.g., cache.t2.micro, cache.t3.micro, cache.t4g.small)."
  }
}

# --- Notes --- #
# 1. Resource Naming:
#    - Use consistent naming with 'name_prefix' across all resources
#    - Environment validation ensures deployment in correct context
#
# 2. Network Design:
#    - Requires private subnets for enhanced security
#    - Security group integration with ASG for controlled access
#
# 3. Redis Configuration:
#    - Supports Redis 7.x with version validation
#    - Flexible cluster architecture with configurable replicas and shards
#    - Automatic failover requires at least one replica
#    - Supports AUTH token when transit encryption is enabled
#
# 4. Monitoring Strategy:
#    - Comprehensive CloudWatch alarms for performance metrics
#    - Configurable thresholds for different environments
#    - CPU and memory monitoring with validated thresholds
#    - Special handling for burstable instances (CPU credits)
#
# 5. Backup Management:
#    - Configurable snapshot retention and timing
#    - Validated time window format for consistent scheduling
#
# 6. Security Measures:
#    - Mandatory KMS encryption for data at rest
#    - Integration with existing security groups
#    - SNS notifications for operational alerts