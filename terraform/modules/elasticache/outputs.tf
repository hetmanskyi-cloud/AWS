# Output the Redis endpoint for connection
output "redis_endpoint" {
  description = "The primary endpoint of the Redis replication group for connection"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# Output the Redis port for connection
output "redis_port" {
  description = "The port of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.port
}
