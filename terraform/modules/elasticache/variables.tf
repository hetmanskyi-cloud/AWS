# --- Variables for ElastiCache Redis Module --- #

# --- Naming and Environment Variables --- #
# Common variables for resource naming and environment configuration.
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

# --- Networking Variables --- #
# Specifies networking details such as VPC and subnet IDs.
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Redis"
  type        = list(string)
}

variable "asg_security_group_id" {
  description = "Security Group ID of ASG instances that require access to Redis"
  type        = string
}

# --- ElastiCache Configuration --- #
# Configuration for Redis version, node setup, and performance tuning.
variable "redis_version" {
  description = "Redis version (e.g., '7.1')"
  type        = string
}

variable "node_type" {
  description = "Node type for Redis (e.g., 'cache.t3.micro')"
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
  description = "Redis port for connections (default: 6379)"
  type        = number
  default     = 6379
  validation {
    condition     = var.redis_port > 0 && var.redis_port <= 65535
    error_message = "The Redis port must be a valid TCP port number between 1 and 65535."
  }
}

# --- Backup and Maintenance Configuration --- #
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

# --- CloudWatch Monitoring Configuration --- #
# Threshold values for CloudWatch alarms related to Redis performance.
variable "redis_cpu_threshold" {
  description = "CPU utilization threshold for Redis alarms"
  type        = number
}

variable "redis_memory_threshold" {
  description = "Memory usage threshold for Redis alarms"
  type        = number
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  type        = string
}

# --- Security Group Configuration --- #
# Optionally reference an external Security Group ID for ElastiCache Redis.
variable "redis_security_group_id" {
  description = "Security Group ID for ElastiCache Redis. Useful for referencing the Redis SG in other modules."
  type        = string
  default     = null
}

# --- Encryption Configuration --- #
# ARN of the KMS key used for encrypting Redis data at rest.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Redis data at rest"
  type        = string
  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "The kms_key_arn variable cannot be empty. Please provide a valid ARN for encrypting data at rest."
  }
}

# --- Enable Freeable Memory Alarm for Redis --- #
# Controls whether the CloudWatch alarm for freeable memory is created.
# Useful for monitoring memory usage and detecting potential bottlenecks.
# Recommended: Enable in all environments.
variable "enable_redis_low_memory_alarm" {
  description = "Enable or disable the freeable memory alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# --- Enable High CPU Utilization Alarm for Redis --- #
# Controls whether the CloudWatch alarm for high CPU utilization is created.
variable "enable_redis_high_cpu_alarm" {
  description = "Enable or disable the high CPU utilization alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# --- Enable Redis Evictions Alarm --- #
# Controls whether the CloudWatch alarm for Redis evictions is created.
# Evictions occur when Redis runs out of memory, potentially leading to data loss.
# Recommended: Enable this alarm for environments where data retention is critical.
variable "enable_redis_evictions_alarm" {
  description = "Enable or disable the Redis evictions alarm."
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

# --- Threshold for Replication Bytes Used Alarm --- #
# Threshold for triggering the replication bytes used alarm.
variable "redis_replication_bytes_threshold" {
  description = "Threshold (in bytes) for replication bytes used alarm in Redis."
  type        = number
  default     = 50000000 # Example threshold: 50 MB
}

# --- Enable Low CPU Credits Alarm for Redis --- #
# Controls whether the CloudWatch alarm for low CPU credits is created.
# Recommended: Enable for burstable instance types (e.g., cache.t2, cache.t3, cache.t4g) to prevent throttling.
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
# 1. Variables are organized into logical sections for naming, networking, configuration, and monitoring.
# 2. 'redis_security_group_id' is optional and used only when referencing an external security group.
# 3. CloudWatch alarm thresholds for CPU and memory are configurable to match performance requirements.
# 4. Snapshot retention and window settings ensure regular backups and maintenance of Redis clusters.