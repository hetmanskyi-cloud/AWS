# --- RDS Module Outputs --- #

# Output the database name
output "db_name" {
  description = "The name of the RDS database"
  value       = var.db_name
}

# Output the master username for the database
output "db_username" {
  description = "The master username for the RDS database"
  value       = var.db_username
}

# Output the security group ID for RDS
output "rds_security_group_id" {
  description = "The ID of the security group for RDS access"
  value       = aws_security_group.rds_sg.id
}

# Output the port number of the RDS database
output "db_port" {
  description = "The port number of the RDS database"
  value       = var.db_port
}

# Outputs the RDS instance address (host) to be used for application database connection.
output "db_host" {
  description = "The address of the RDS instance to be used as DB_HOST in WordPress configuration."
  value       = aws_db_instance.db.address
}

# Outputs the RDS endpoint (host and port) to simplify database connection settings in applications.
output "db_endpoint" {
  description = "The endpoint of the RDS instance, including host and port."
  value       = aws_db_instance.db.endpoint
}

# Output for Monitoring Role ARN, used when enabling monitoring
output "rds_monitoring_role_arn" {
  description = "The ARN of the IAM role for RDS Enhanced Monitoring"
  value       = aws_iam_role.rds_monitoring_role.arn
}

output "lambda_create_replica_arn" {
  description = "ARN of the Lambda function to create a read replica"
  value       = aws_lambda_function.create_read_replica.arn
}

output "lambda_delete_replica_arn" {
  description = "ARN of the Lambda function to delete a read replica"
  value       = aws_lambda_function.delete_read_replica.arn
}

# Output for the primary RDS instance identifier
output "rds_db_instance_id" {
  description = "Identifier of the primary RDS database instance"
  value       = aws_db_instance.db.id
}

# Output for the RDS replicas identifiers
output "rds_read_replicas_ids" {
  description = "Identifiers of the RDS read replicas"
  value       = [for replica in aws_db_instance.read_replica : replica.id]
}

output "db_instance_identifier" {
  value       = aws_db_instance.db.id
  description = "The identifier of the RDS instance"
}
