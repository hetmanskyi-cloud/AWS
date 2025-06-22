# Terraform version and provider requirements
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# --- Main Configuration for RDS --- #
# Configures a primary RDS instance with encryption and monitoring,
# CloudWatch Log Groups for error and slowquery logs,
# optional read replicas for high availability, and subnet group for network isolation.

# --- RDS Database Instance Configuration --- #
# Defines the primary RDS database instance resource.
#tfsec:ignore:builtin.aws.rds.aws0177
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
  #tfsec:ignore:aws-rds-enable-deletion-protection
  deletion_protection       = var.rds_deletion_protection                                                             # Deletion protection (controlled by variable). Production: set to 'true'.
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-${var.environment}"
  })

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-params-${var.environment}"
  })
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-logs-${var.environment}"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# --- Conditional Log Group for RDS Enhanced Monitoring --- #
# Creates and manages the default RDSOSMetrics log group via Terraform.
# AWS automatically creates a log group named "RDSOSMetrics" when Enhanced Monitoring is enabled,
# but it is unmanaged (no encryption, no tags).
# By explicitly creating this group with the same name, we override the default behavior,
# enabling Terraform to manage encryption, retention, and tags — ensuring full IaC control.
resource "aws_cloudwatch_log_group" "rds_os_metrics" {
  count             = var.enable_rds_monitoring ? 1 : 0
  name              = "RDSOSMetrics" # DO NOT change this name — required to override AWS default behavior.
  retention_in_days = var.rds_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-os-metrics-${var.environment}"
  })

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group-${var.environment}"
  })
}

# --- Read Replica Configuration --- #
# Defines RDS read replicas, inheriting configuration from the primary DB instance.
# These replicas improve read scalability and can be placed across AZs for high availability.

# checkov:skip=CKV_AWS_157 Justification: Read replicas do not support 'multi_az' – AWS handles HA differently for replicas
# tfsec:ignore:builtin.aws.rds.aws0177
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
  #tfsec:ignore:aws-rds-enable-deletion-protection
  deletion_protection = var.rds_deletion_protection
  monitoring_interval = aws_db_instance.db.monitoring_interval
  monitoring_role_arn = aws_db_instance.db.monitoring_role_arn

  # Performance Insights
  performance_insights_enabled    = aws_db_instance.db.performance_insights_enabled
  performance_insights_kms_key_id = aws_db_instance.db.performance_insights_kms_key_id

  # Other Configurations

  # Automatically applies minor version upgrades during maintenance windows.
  # Recommended for non-production environments. For production, set to false if strict version control is needed.
  auto_minor_version_upgrade      = true                    # Enable automatic minor version upgrades.
  copy_tags_to_snapshot           = true                    # Copy tags to DB snapshots.
  publicly_accessible             = false                   # Ensure read replicas are not publicly accessible for security best practices.
  skip_final_snapshot             = var.skip_final_snapshot # Skip final snapshot on deletion (for code consistency).
  enabled_cloudwatch_logs_exports = aws_db_instance.db.enabled_cloudwatch_logs_exports

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-replica-${var.environment}-${count.index}" # Unique name per read replica
  })

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
#    - Consider enabling `delete_automated_backups = false` in dev/test environments to debug issues post-deletion.
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
#
# 6. Secrets and Password Management:
#    - RDS credentials (username and password) are passed directly via Terraform variables (db_username, db_password).
#    - Password is stored in the Terraform state file but marked as sensitive to reduce accidental exposure.
#    - Direct integration with AWS Secrets Manager is NOT required here; application (e.g., WordPress) pulls credentials from a secret independently.
#    - If needed, password rotation should be managed externally or via additional automation (AWS Lambda, Secrets Manager rotation).
#    - If integrating with Secrets Manager, avoid passing credentials directly and fetch them via data sources.
#
# 7. Future Consideration:
#    - For better scalability and high availability, consider migrating to Amazon Aurora in the future.
#    - Aurora provides built-in clustering, shared storage, and improved read scaling with 'aws_rds_cluster' resources.
#    - Optional (future enhancement):
#      - Consider adding `read_replica_source_db_instance_identifier` explicitly for clarity,
#      especially if planning cross-region replication or complex architectures.
#    - Additional logging exports (e.g., "general", "audit") may improve observability in production.
