# --- Naming and Environment Variables --- #

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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Redis"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security Group ID of EC2 instances"
  type        = string
}

# --- ElastiCache Configuration --- #

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
  description = "Redis port (default: 6379)"
  type        = number
}

variable "snapshot_retention_limit" {
  description = "Number of snapshots to retain"
  type        = number
}

variable "snapshot_window" {
  description = "Preferred window for snapshots (e.g., '03:00-04:00')"
  type        = string
  default     = "03:00-04:00"
}

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

variable "redis_security_group_id" {
  description = "Security Group ID for ElastiCache Redis, if needed in other modules"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting Firehose data in the S3 bucket"
  type        = string
}
