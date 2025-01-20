# --- RDS Module Outputs --- #

# --- Database Name --- #
# Outputs the name of the initial RDS database created.
output "db_name" {
  description = "The name of the RDS database"
  value       = var.db_name
}

# --- Master Username --- #
# Outputs the master username for managing the RDS instance.
output "db_username" {
  description = "The master username for the RDS database"
  value       = var.db_username
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
# Outputs the host address of the RDS instance to be used for database connections.
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
# Outputs the ARN of the IAM role used for RDS Enhanced Monitoring.
output "rds_monitoring_role_arn" {
  description = "The ARN of the IAM role for RDS Enhanced Monitoring"
  value       = length(aws_iam_role.rds_monitoring_role) > 0 ? aws_iam_role.rds_monitoring_role[0].arn : null
}

# --- Read Replicas Identifiers --- #
# Outputs a list of identifiers for all RDS read replicas.
# Note: Returns an empty list if no read replicas are configured.
output "rds_read_replicas_ids" {
  description = "Identifiers of the RDS read replicas"
  value       = [for replica in aws_db_instance.read_replica : replica.id]
}

# --- RDS Instance Identifier --- #
# Outputs the unique identifier of the RDS instance.
# Note: This is the primary and recommended output for referencing the RDS instance identifier,
# ensuring consistency with AWS terminology and Terraform's resource naming conventions.
output "db_instance_identifier" {
  description = "The identifier of the RDS instance"
  value       = aws_db_instance.db.id
}

# --- Notes --- #
# 1. Outputs include essential details for connecting to the RDS instance, such as host, port, and endpoint.
# 2. The 'rds_security_group_id' can be referenced to manage access control in other modules.
# 3. Monitoring Role ARN is provided if Enhanced Monitoring is enabled for the RDS instance.
# 4. The list of read replicas helps in distributing read workloads for improved performance and availability.