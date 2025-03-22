# --- Main Configuration for RDS --- #
# Configures a primary RDS instance with encryption and monitoring,
# CloudWatch Log Groups for error and slowquery logs,
# optional read replicas for high availability, and subnet group for network isolation.

# --- RDS Database Instance Configuration --- #
# Defines the primary RDS database instance resource.
resource "aws_db_instance" "db" {
  identifier        = "${var.name_prefix}-db-${var.environment}" # Unique identifier for the RDS instance.
  allocated_storage = var.allocated_storage                      # Storage size in GB.
  instance_class    = var.instance_class                         # RDS instance class.
  engine            = var.engine                                 # Database engine (e.g., "mysql").
  engine_version    = var.engine_version                         # Database engine version.
  username          = var.db_username                            # Master username.
  password          = var.db_password                            # Master password.
  db_name           = var.db_name                                # Initial database name.
  port              = var.db_port                                # Database port (e.g., 3306 for MySQL).
  multi_az          = var.multi_az                               # Enable Multi-AZ for high availability.

  # Security and Networking
  vpc_security_group_ids = [aws_security_group.rds_sg.id]           # Security Group for network access control.
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name # DB Subnet Group for private subnet placement.

  # Storage Encryption
  storage_encrypted = true            # Enable encryption at rest.
  kms_key_id        = var.kms_key_arn # KMS Key ARN for storage encryption (from KMS module).

  # Parameter Group for Enforcing TLS/SSL  
  parameter_group_name = aws_db_parameter_group.rds_params.name

  # Backup Configuration
  backup_retention_period = var.backup_retention_period # Backup retention period (days).
  backup_window           = var.backup_window           # Preferred backup window.

  # Auto Minor Version Upgrade & Tagging
  auto_minor_version_upgrade = true # Enable automatic minor version upgrades.
  copy_tags_to_snapshot      = true # Copy tags to DB snapshots.

  # Deletion & Final Snapshot Configuration
  deletion_protection       = var.rds_deletion_protection                                                             # Deletion protection (controlled by variable). Production: set to 'true'. # tfsec:ignore:builtin.aws.rds.aws0177
  skip_final_snapshot       = var.skip_final_snapshot                                                                 # Skip final snapshot on instance deletion.
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-final-snapshot-${var.environment}" # Final snapshot name.
  delete_automated_backups  = true                                                                                    # Delete automated backups on instance deletion.

  # Performance Insights
  performance_insights_enabled    = var.performance_insights_enabled                          # Enable Performance Insights (controlled by variable).
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null # KMS key for Performance Insights encryption (if enabled).

  # Enhanced Monitoring
  monitoring_interval = var.enable_rds_monitoring ? 60 : 0                                                    # Enhanced Monitoring interval (seconds, 60 if enabled, 0 if disabled).
  monitoring_role_arn = var.enable_rds_monitoring ? try(aws_iam_role.rds_monitoring_role[0].arn, null) : null # IAM Role ARN for Enhanced Monitoring (conditional, uses 'try').

  # CloudWatch Logs Configuration
  enabled_cloudwatch_logs_exports = [ # CloudWatch Logs exported (configurable).
    "error",                          # Critical errors and crashes.
    "slowquery"                       # Query performance tuning.
  ]

  # Tags
  tags = {
    Name        = "${var.name_prefix}-db-${var.environment}" # Resource name tag.
    Environment = var.environment                            # Environment tag.
  }

  # Dependencies
  depends_on = [aws_security_group.rds_sg, aws_cloudwatch_log_group.rds_log_group] # Ensure SG and Log Groups are created first.
}

# --- RDS Parameter Group for Enforcing TLS --- #
# Enforces SSL/TLS connections to the RDS instance by setting 'require_secure_transport = 1'.
resource "aws_db_parameter_group" "rds_params" {
  name        = "${var.name_prefix}-rds-params-${var.environment}"
  family      = "mysql8.0" # Required family for MySQL 8.0
  description = "RDS parameter group enforcing TLS for MySQL 8.0"

  parameter {
    name  = "require_secure_transport"
    value = "1"
  }

  tags = {
    Name        = "${var.name_prefix}-rds-params-${var.environment}"
    Environment = var.environment
  }
}

# --- CloudWatch Log Groups for RDS --- #
# Creates CloudWatch Log Groups for RDS error and slowquery logs using 'for_each' to iterate over log types.
resource "aws_cloudwatch_log_group" "rds_log_group" {
  for_each = toset([
    "/aws/rds/instance/${var.name_prefix}-db-${var.environment}/error",
    "/aws/rds/instance/${var.name_prefix}-db-${var.environment}/slowquery"
  ])

  name              = each.key
  retention_in_days = var.rds_log_retention_days # Adjust carefully to control CloudWatch costs
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.name_prefix}-rds-logs"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --- Conditional Log Group for RDS Enhanced Monitoring --- #
# Conditional CloudWatch Log Group for RDS OS Metrics (created only when Enhanced Monitoring is enabled).
resource "aws_cloudwatch_log_group" "rds_os_metrics" {
  count             = var.enable_rds_monitoring ? 1 : 0
  name              = "RDSOSMetrics"
  retention_in_days = var.rds_log_retention_days # Adjust carefully to control CloudWatch costs
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.name_prefix}-rds-os-metrics-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --- RDS Subnet Group Configuration --- #
# Defines a DB subnet group for RDS to specify private subnets for deployment.
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.name_prefix}-db-subnet-group-${var.environment}" # Unique name for the DB Subnet Group.
  description = "Subnet group for RDS ${var.engine} instance."          # Description for the DB Subnet Group.
  subnet_ids  = var.private_subnet_ids                                  # Assign RDS to private subnets.

  tags = {
    Name        = "${var.name_prefix}-db-subnet-group-${var.environment}" # Tag with dynamic name.
    Environment = var.environment                                         # Environment tag.
  }
}

# --- Read Replica Configuration --- #
# Defines RDS read replicas, inheriting configuration from the primary DB instance.
resource "aws_db_instance" "read_replica" {
  count = var.read_replicas_count # Creates read replicas based on 'read_replicas_count' variable.

  identifier = "${var.name_prefix}-replica${count.index}-${var.environment}"

  # Inherited Configuration from Primary Instance
  instance_class          = aws_db_instance.db.instance_class
  engine                  = aws_db_instance.db.engine
  engine_version          = aws_db_instance.db.engine_version
  allocated_storage       = aws_db_instance.db.allocated_storage
  db_subnet_group_name    = aws_db_instance.db.db_subnet_group_name
  vpc_security_group_ids  = aws_db_instance.db.vpc_security_group_ids
  storage_encrypted       = aws_db_instance.db.storage_encrypted
  kms_key_id              = aws_db_instance.db.kms_key_id
  backup_retention_period = aws_db_instance.db.backup_retention_period
  backup_window           = aws_db_instance.db.backup_window
  deletion_protection     = var.rds_deletion_protection # tfsec:ignore:builtin.aws.rds.aws0177
  monitoring_interval     = aws_db_instance.db.monitoring_interval
  monitoring_role_arn     = aws_db_instance.db.monitoring_role_arn

  # Performance Insights
  performance_insights_enabled    = aws_db_instance.db.performance_insights_enabled
  performance_insights_kms_key_id = aws_db_instance.db.performance_insights_kms_key_id

  # Other Configurations
  auto_minor_version_upgrade      = true                    # Enable automatic minor version upgrades.
  copy_tags_to_snapshot           = true                    # Copy tags to DB snapshots.
  publicly_accessible             = false                   # Ensure read replicas are not publicly accessible for security best practices.
  skip_final_snapshot             = var.skip_final_snapshot # Skip final snapshot on deletion (for code consistency).
  enabled_cloudwatch_logs_exports = aws_db_instance.db.enabled_cloudwatch_logs_exports

  # Tags
  tags = merge(
    aws_db_instance.db.tags,
    { Name = "${var.name_prefix}-replica-${count.index}" } # Read Replica specific Name tag.
  )

  # Dependencies
  depends_on = [aws_db_instance.db] # Ensure replica creation after primary instance.
}

# --- Notes --- #
# 1. Security:
#    - Encryption at rest is enabled for the RDS instance using KMS.
#    - Encryption in transit (TLS/SSL) is enforced by the DB Parameter Group ('require_secure_transport = 1').
#    - KMS keys are used for both storage encryption and CloudWatch logs encryption.
#
# 2. High Availability:
#    - Multi-AZ deployment is configurable via 'var.multi_az' for automatic failover.
#    - Optional read replicas are created for read scaling and high availability.
#
# 3. Backup and Protection:
#    - Configurable backup retention and deletion protection to prevent accidental data loss.
#    - Final snapshot creation is controlled via 'skip_final_snapshot' for production safety.
#    - Enhanced Monitoring is conditionally enabled with a dedicated IAM role.
#
# 4. Logging Strategy:
#    - CloudWatch Log Groups are created for 'error' and 'slowquery' logs.
#    - In production, consider enabling 'general' and 'audit' logs for better observability and compliance.
#    - Monitor CloudWatch log volume to control operational costs.
#
# 5. Best Practices:
#    - Regularly review and adjust log retention periods to manage storage and expenses.
#    - Maintain strict tagging for all RDS resources for easy identification and cost allocation.
#    - Periodically validate parameter groups to ensure security and performance settings are up to date.