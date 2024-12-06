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
  kms_key_id                 = var.kms_key_arn

  # Backup configuration
  snapshot_retention_limit = var.snapshot_retention_limit # Number of days to retain backups
  snapshot_window          = var.snapshot_window          # Preferred time window for snapshots

  # Optional attributes for enhanced security and monitoring
  at_rest_encryption_enabled = true # Enables encryption at rest
  transit_encryption_enabled = true # Enables in-transit encryption

  # Tags for resource identification
  tags = {
    Name        = "${var.name_prefix}-redis-replication-group"
    Environment = var.environment
  }
}

# --- ElastiCache Parameter Group --- #
resource "aws_elasticache_parameter_group" "redis_params" {
  name        = "${var.name_prefix}-redis-params"
  family      = "redis7"
  description = "Default parameter group for Redis 7.x"

  tags = {
    Name        = "${var.name_prefix}-redis-params"
    Environment = var.environment
  }
}