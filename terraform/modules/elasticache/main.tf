# --- ElastiCache Subnet Group --- #
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.name_prefix}-redis-subnet-group"
  description = "Subnet group for ElastiCache Redis"
  subnet_ids  = var.private_subnet_ids
  tags = {
    Name        = "${var.name_prefix}-redis-subnet-group"
    Environment = var.environment
  }
}

# --- ElastiCache Replication Group (Redis) --- #
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.name_prefix}-redis-${var.environment}"        # Unique ID for the replication group
  description                = "Redis replication group for ${var.name_prefix}"     # Description for the replication group
  engine                     = "redis"                                              # ElastiCache engine type
  engine_version             = var.redis_version                                    # Redis version (e.g., 7.1)
  node_type                  = var.node_type                                        # Instance type (e.g., cache.t3.micro)
  replicas_per_node_group    = var.replicas_per_node_group                          # Number of replicas per shard
  num_node_groups            = var.num_node_groups                                  # Number of shards (node groups)
  automatic_failover_enabled = var.replicas_per_node_group > 0 ? true : false       # Enables failover if replicas exist
  parameter_group_name       = aws_elasticache_parameter_group.redis_params.name    # Parameter group for Redis
  port                       = var.redis_port                                       # Port for Redis connections
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name # Subnet group for deployment
  security_group_ids         = [aws_security_group.redis_sg.id]                     # Security group IDs for network access

  # Backup configuration
  snapshot_retention_limit = var.snapshot_retention_limit # Number of days to retain backups
  snapshot_window          = var.snapshot_window          # Preferred time window for snapshots

  # Optional attributes for enhanced security and monitoring
  at_rest_encryption_enabled = true # Enables encryption at rest
  transit_encryption_enabled = true # Enables in-transit encryption

  # Tags for resource identification
  tags = {
    Name        = "${var.name_prefix}-redis-cluster"
    Environment = var.environment
  }
}

# --- ElastiCache Parameter Group --- #
resource "aws_elasticache_parameter_group" "redis_params" {
  name        = "${var.name_prefix}-redis-params"
  family      = "redis7"
  description = "Custom parameter group for Redis 7.1 with enhanced settings"

  # Memory management settings
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # Eviction policy for memory management
  }

  parameter {
    name  = "maxmemory"
    value = "858993459" # 80% of 1 GB (approximately 859 MB) in bytes
  }

  # Hash table settings
  parameter {
    name  = "hash-max-ziplist-entries"
    value = "512" # Maximum number of entries in a hash for optimized storage
  }

  parameter {
    name  = "hash-max-listpack-value"
    value = "64" # Maximum value size in a hash for optimized storage
  }

  # Security settings
  parameter {
    name  = "rename-command"
    value = "CONFIG \"\"" # Disable the CONFIG command for security
  }

  # Network settings
  parameter {
    name  = "tcp-keepalive"
    value = "300" # Keep-alive interval (300 seconds)
  }

  parameter {
    name  = "timeout"
    value = "60" # Idle client timeout (60 seconds)
  }
}
