# Output the Redis port for connection
output "redis_port" {
  description = "The port of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.port
}

# Output the Redis endpoint for connection
output "redis_endpoint" {
  description = "The primary endpoint of the Redis replication group for connection"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_security_group_id" {
  description = "The ID of the Security Group for ElastiCache Redis"
  value       = aws_security_group.redis_sg.id
}
