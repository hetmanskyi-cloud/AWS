# --- ElastiCache Subnet Group --- #
# Creates a subnet group for ElastiCache Redis, enabling deployment in specified private subnets.
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.name_prefix}-redis-subnet-group"
  description = "Subnet group for ElastiCache Redis"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "${var.name_prefix}-redis-subnet-group"
    Environment = var.environment
  }
}

locals {

  kms_key_id = var.enable_kms_role && length(aws_iam_role.elasticache_kms_role) > 0 ? aws_iam_role.elasticache_kms_role[0].arn : var.kms_key_arn
}

# --- ElastiCache Replication Group (Redis) --- #
# Sets up a Redis replication group with automatic failover, encryption, and backup configuration.
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.name_prefix}-redis-${var.environment}"        # Unique ID for the replication group.
  description                = "Redis replication group for ${var.name_prefix}"     # Description for the replication group.
  engine                     = "redis"                                              # Specifies Redis as the engine type.
  engine_version             = var.redis_version                                    # Redis version (e.g., 7.1).
  node_type                  = var.node_type                                        # Instance type for Redis nodes (e.g., cache.t3.micro).
  replicas_per_node_group    = var.replicas_per_node_group                          # Number of replicas per shard.
  num_node_groups            = var.num_node_groups                                  # Number of shards (node groups).
  automatic_failover_enabled = var.replicas_per_node_group > 0 ? true : false       # Enables failover only if replicas exist.
  parameter_group_name       = aws_elasticache_parameter_group.redis_params.name    # Specifies the parameter group for Redis.
  port                       = var.redis_port                                       # Port for Redis connections.
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name # Subnet group for deployment.
  security_group_ids         = [aws_security_group.redis_sg.id]                     # Security group for controlling network access.
  kms_key_id                 = local.kms_key_id                                     # KMS key for encrypting data at rest.

  # --- Backup Configuration --- #
  snapshot_retention_limit = var.snapshot_retention_limit # Number of days to retain backups.
  snapshot_window          = var.snapshot_window          # Preferred time window for snapshots.

  # --- Security and Encryption --- #
  at_rest_encryption_enabled = true # Encrypts data at rest using KMS.
  transit_encryption_enabled = true # Encrypts data in transit between nodes.

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-redis-replication-group"
    Environment = var.environment
  }
}

# --- ElastiCache Parameter Group --- #
# Creates a custom parameter group for Redis 7.x to manage Redis-specific settings.
resource "aws_elasticache_parameter_group" "redis_params" {
  name        = "${var.name_prefix}-redis-params"
  family      = "redis7" # Specifies Redis version family.
  description = "Default parameter group for Redis 7.x"

  tags = {
    Name        = "${var.name_prefix}-redis-params"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. The ElastiCache Subnet Group ensures Redis is deployed in the specified private subnets.
# 2. The Replication Group includes encryption at rest and in transit for enhanced security.
# 3. Backups are retained for the configured number of days (snapshot_retention_limit).
# 4. Automatic failover is enabled when replicas are configured to ensure high availability.
# 5. Tags are applied to all resources for identification and management across environments.
# 6. The Parameter Group uses the Redis 7.x family and can be extended to customize Redis settings.