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

# --- ElastiCache Replication Group (Redis) --- #
# Sets up a Redis replication group with automatic failover, encryption, and backup configuration.
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.name_prefix}-redis-${var.environment}"          # Unique ID for the replication group.
  description                = "Redis replication group for ${var.name_prefix}"       # Description for the replication group.
  engine                     = "redis"                                                # Specifies Redis as the engine type.
  engine_version             = var.redis_version                                      # Redis version (e.g., 7.1).
  node_type                  = var.node_type                                          # Instance type for Redis nodes (e.g., cache.t3.micro).
  replicas_per_node_group    = var.replicas_per_node_group                            # Number of replicas per shard.
  num_node_groups            = var.num_node_groups                                    # Number of shards (node groups).
  automatic_failover_enabled = var.enable_failover && var.replicas_per_node_group > 0 # Enables failover only if replicas exist.
  parameter_group_name       = aws_elasticache_parameter_group.redis_params.name      # Specifies the parameter group for Redis.
  port                       = var.redis_port                                         # Port for Redis connections.
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name   # Subnet group for deployment.
  security_group_ids         = [aws_security_group.redis_sg.id]                       # Security group for controlling network access.

  # Notes on KMS Key Usage
  # Ensure the kms_key_arn is specified to enable data encryption at rest.
  # If left empty, data encryption will not be applied, which is not recommended for production environments.
  kms_key_id = var.kms_key_arn # KMS key for encrypting data at rest.

  # Backup Configuration
  snapshot_retention_limit = var.snapshot_retention_limit # Number of days to retain backups.
  snapshot_window          = var.snapshot_window          # Preferred time window for snapshots.

  # Security and Encryption
  at_rest_encryption_enabled = true # Encrypts data at rest using KMS.
  transit_encryption_enabled = true # Encrypts data in transit between nodes.

  lifecycle {
    prevent_destroy = false # Prevent accidental deletion
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-redis-replication-group"
    Environment = var.environment
  }
}

# --- ElastiCache Parameter Group --- #
# Creates a custom parameter group for Redis with version-specific family.
# Uses default AWS parameters which are well-optimized for most use cases.
resource "aws_elasticache_parameter_group" "redis_params" {
  name        = "${var.name_prefix}-redis-params"
  family      = "redis${split(".", var.redis_version)[0]}" # Specifies Redis version family.
  description = "Parameter group for Redis ${var.redis_version} with default settings"

  tags = {
    Name        = "${var.name_prefix}-redis-params"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. The ElastiCache Subnet Group ensures Redis is deployed in the specified private subnets.
# 2. The Replication Group includes encryption at rest and in transit for enhanced security.
# 3. Backups are retained for the configured number of days (snapshot_retention_limit).
# 4. Automatic failover is enabled when replicas are configured for high availability.
# 5. Parameter Group uses dynamic Redis family based on the specified version.
# 6. All resources use consistent tagging for proper resource management.