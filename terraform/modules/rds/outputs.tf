# --- RDS Module Outputs --- #

# --- Database Name --- #
# Outputs the name of the initial RDS database created.
output "db_name" {
  description = "The name of the RDS database"
  value       = var.db_name
}

# --- Security Group ID --- #
# Outputs the ID of the Security Group created for RDS to control access.
output "rds_security_group_id" {
  description = "The ID of the security group for RDS access"
  value       = aws_security_group.rds_sg.id
}

# --- RDS Port Number --- #
# Outputs the port number used for database connections.
output "db_port" {
  description = "The port number of the RDS database"
  value       = var.db_port
}

# --- RDS Instance Host Address --- #
# Outputs the host address of the RDS instance for database connections (e.g., for DB_HOST in WordPress).
output "db_host" {
  description = "The address of the RDS instance to be used as DB_HOST in WordPress configuration."
  value       = aws_db_instance.db.address
}

# --- RDS Endpoint --- #
# Outputs the full endpoint of the RDS instance, including host and port.
output "db_endpoint" {
  description = "The endpoint of the RDS instance, including host and port."
  value       = aws_db_instance.db.endpoint
}

# --- Monitoring Role ARN --- #
# Outputs the ARN of the IAM role used for RDS Enhanced Monitoring (null if monitoring is disabled).
output "rds_monitoring_role_arn" {
  description = "The ARN of the IAM role for RDS Enhanced Monitoring (null if monitoring is disabled)"
  value       = try(aws_iam_role.rds_monitoring_role[0].arn, null)
}

# --- Read Replicas Identifiers --- #
# Outputs a list of identifiers for all RDS read replicas. Returns an empty list if no read replicas are configured.
output "rds_read_replicas_ids" {
  description = "Identifiers of the RDS read replicas"
  value       = [for replica in aws_db_instance.read_replica : replica.id]
}

# --- RDS Instance Identifier --- #
# Outputs the unique identifier of the RDS instance. Recommended output for referencing the RDS instance.
output "db_instance_identifier" {
  description = "The identifier of the RDS instance"
  value       = aws_db_instance.db.id
}

# --- Read Replicas Endpoints --- #
# Outputs a list of endpoints for all RDS read replicas. Returns an empty list if no read replicas are configured.
output "rds_read_replicas_endpoints" {
  description = "Endpoints of the RDS read replicas"
  value       = [for replica in aws_db_instance.read_replica : replica.endpoint]
}

# --- RDS Instance ARN --- #
# Outputs the ARN (Amazon Resource Name) of the RDS instance.
output "db_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.db.arn
}

# --- RDS Instance Status --- #
# Outputs the current status of the RDS instance (e.g., "available", "creating").
output "db_status" {
  description = "The current status of the RDS instance"
  value       = aws_db_instance.db.status
}

# --- CloudWatch Log Group Names --- #
# Outputs the names of the CloudWatch Log Groups created for RDS logs (error and slowquery).
output "rds_log_group_names" {
  description = "The names of the CloudWatch Log Groups for RDS logs (error and slowquery)"
  value       = [for lg in aws_cloudwatch_log_group.rds_log_group : lg.name]
}

# --- Notes --- #
# 1. Outputs provide essential details for connecting to and managing the RDS instance, including connection parameters (host, port, endpoint).
# 2. 'rds_security_group_id' output allows for referencing the RDS Security Group in other modules for access control configuration.
# 3. 'rds_monitoring_role_arn' output provides the IAM Role ARN for Enhanced Monitoring, available when monitoring is enabled.
# 4. Read replica outputs ('rds_read_replicas_ids', 'rds_read_replicas_endpoints') facilitate workload distribution across replicas for improved read performance and high availability.