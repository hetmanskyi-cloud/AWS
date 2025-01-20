# --- Outputs for ElastiCache Redis --- #

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

# Failover status for Redis replication group
output "failover_status" {
  description = "Indicates if failover is enabled for Redis replication group."
  value       = aws_elasticache_replication_group.redis.automatic_failover_enabled
}

# --- Notes --- #
# 1. These outputs provide essential details for connecting to and managing the Redis replication group.
# 2. The 'redis_endpoint' is the primary connection point for applications and clients.
# 3. The 'redis_port' allows clients to determine the correct port for Redis connections.
# 4. The 'redis_security_group_id' can be referenced to manage access rules or integrate with other modules.