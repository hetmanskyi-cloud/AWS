# --- ElastiCache Module Outputs --- #

# --- Redis Port --- #
# Outputs the port number for the Redis replication group to allow client connections.
output "redis_port" {
  description = "The port of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.port
}

# --- Redis Endpoint --- #
# Outputs the primary endpoint for connecting to the Redis replication group.
output "redis_endpoint" {
  description = "The primary endpoint of the Redis replication group for connection"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# --- Redis Security Group ID --- #
# Outputs the ID of the Security Group used to control access to the Redis replication group.
output "redis_security_group_id" {
  description = "The ID of the Security Group for ElastiCache Redis. Used for integrating with other modules."
  value       = aws_security_group.redis_sg.id
}

# --- Redis Replication Group ID --- #
# Outputs the ID of the Redis replication group for integration and monitoring.
output "redis_replication_group_id" {
  description = "The ID of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.id
}

# --- Redis Reader Endpoint --- #
# Outputs the reader endpoint for read replicas when available
output "redis_reader_endpoint" {
  description = "The reader endpoint for Redis read replicas (only available if replicas_per_node_group > 0)."
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

# --- Redis ARN --- #
output "redis_arn" {
  description = "The ARN of the Redis replication group. Useful for IAM policies."
  value       = aws_elasticache_replication_group.redis.arn
}

# Failover status for Redis replication group
output "failover_status" {
  description = "Indicates if automatic failover is enabled for the Redis replication group. True when replicas exist and failover is configured."
  value       = aws_elasticache_replication_group.redis.automatic_failover_enabled
}

# --- Notes --- #
# 1. Connection Information:
#    - 'redis_endpoint': Primary endpoint for write operations
#    - 'redis_reader_endpoint': Endpoint for read operations when replicas exist
#    - 'redis_port': Port number for client connections
# 2. Status and Configuration:
#    - 'failover_status': Automatic failover configuration
# 3. Integration Points:
#    - 'redis_security_group_id': For security group management
#    - 'redis_arn': For IAM policies and permissions
#    - 'redis_replication_group_id': For monitoring and management