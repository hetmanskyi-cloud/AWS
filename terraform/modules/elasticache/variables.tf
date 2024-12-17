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

variable "ec2_security_group_id" {
  description = "Security Group ID of EC2 instances that require access to Redis"
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
}

variable "num_node_groups" {
  description = "Number of shards (node groups)"
  type        = number
}

variable "redis_port" {
  description = "Redis port for connections (default: 6379)"
  type        = number
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
  description = "Security Group ID for ElastiCache Redis, if needed in other modules"
  type        = string
  default     = null
}

# --- Encryption Configuration --- #
# ARN of the KMS key used for encrypting Redis data at rest.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Redis data at rest"
  type        = string
}

# --- Notes --- #
# 1. Variables are organized into logical sections for naming, networking, configuration, and monitoring.
# 2. 'redis_security_group_id' is optional and used only when referencing an external security group.
# 3. CloudWatch alarm thresholds for CPU and memory are configurable to match performance requirements.
# 4. Snapshot retention and window settings ensure regular backups and maintenance of Redis clusters.