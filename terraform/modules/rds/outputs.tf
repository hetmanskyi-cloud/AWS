# --- RDS Module Outputs --- #

# Output the endpoint of the RDS database
output "db_endpoint" {
  description = "The endpoint of the RDS database"
  value       = aws_db_instance.db.endpoint
}

# Output the database name
output "db_name" {
  description = "The name of the RDS database"
  value       = var.db_name
}

# Output the master username for the database
output "db_username" {
  description = "The master username for the RDS database"
  value       = var.username
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

# Output for Monitoring Role ARN, used when enabling monitoring
output "rds_monitoring_role_arn" {
  description = "The ARN of the IAM role for RDS Enhanced Monitoring"
  value       = aws_iam_role.rds_monitoring_role.arn
}