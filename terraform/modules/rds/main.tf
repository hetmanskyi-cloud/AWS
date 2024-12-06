# --- RDS Database Instance Configuration --- #

# Define the primary RDS database instance
resource "aws_db_instance" "db" {
  identifier        = "${var.name_prefix}-db-${var.environment}" # Unique identifier for the RDS instance
  allocated_storage = var.allocated_storage                      # Storage size in GB
  instance_class    = var.instance_class                         # RDS instance class
  engine            = var.engine                                 # Database engine (e.g., "mysql")
  engine_version    = var.engine_version                         # Database engine version
  username          = var.db_username                            # Master username
  password          = var.db_password                            # Master password (sensitive)
  db_name           = var.db_name                                # Initial database name
  port              = var.db_port                                # Database port (e.g., 3306 for MySQL)
  multi_az          = var.multi_az                               # Enable Multi-AZ deployment

  # Security and Networking
  vpc_security_group_ids = [aws_security_group.rds_sg.id]           # Security group IDs for access control
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name # Name of the DB subnet group for RDS

  # Storage Encryption
  storage_encrypted = true            # Enable encryption at rest
  kms_key_id        = var.kms_key_arn # KMS key ARN for encryption (provided by KMS module)

  # Backup Configuration
  backup_retention_period = var.backup_retention_period # Number of days to retain backups
  backup_window           = var.backup_window           # Preferred backup window

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true # Enable automatic minor version upgrade

  # Copy Tags to Snapshots
  copy_tags_to_snapshot = true # Enable copying tags to snapshots

  # Deletion Protection
  deletion_protection = var.deletion_protection # Enable or disable deletion protection

  # Final Snapshot Configuration
  skip_final_snapshot       = true                                                   # Skip final snapshot on deletion
  final_snapshot_identifier = "${var.name_prefix}-final-snapshot-${var.environment}" # Final snapshot name
  delete_automated_backups  = true                                                   # Delete automated backups when the instance is deleted

  # Performance Insights
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null

  # Monitoring
  monitoring_interval = var.enable_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_monitoring ? aws_iam_role.rds_monitoring_role.arn : null

  # Tags for resource identification
  tags = {
    Name        = "${var.name_prefix}-db-${var.environment}" # Resource name tag
    Environment = var.environment                            # Environment tag
  }

  # Ensure the security group is created first
  depends_on = [aws_security_group.rds_sg]
}

# --- RDS Subnet Group Configuration --- #

# Define a DB subnet group for RDS to specify private subnets for deployment
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.name_prefix}-db-subnet-group-${var.environment}" # Unique name for the DB subnet group
  description = "Subnet group for RDS ${var.engine} instance"           # Description for the DB subnet group
  subnet_ids  = var.private_subnet_ids                                  # Assign RDS to private subnets

  tags = {
    Name        = "${var.name_prefix}-db-subnet-group-${var.environment}" # Tag with dynamic name
    Environment = var.environment                                         # Environment tag
  }
}

# --- Read Replica Configuration --- #

# Define RDS read replicas
resource "aws_db_instance" "read_replica" {
  count = var.read_replicas_count

  identifier = "${var.name_prefix}-replica${count.index}-${var.environment}"

  # Inherit configuration from the primary DB instance
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
  deletion_protection     = aws_db_instance.db.deletion_protection
  monitoring_interval     = aws_db_instance.db.monitoring_interval
  monitoring_role_arn     = aws_db_instance.db.monitoring_role_arn

  # Performance Insights for replicas
  performance_insights_enabled    = aws_db_instance.db.performance_insights_enabled
  performance_insights_kms_key_id = aws_db_instance.db.performance_insights_kms_key_id

  publicly_accessible = false # Read replicas should not be publicly accessible

  skip_final_snapshot = true # Do not create a final snapshot during deletion

  tags = merge(
    aws_db_instance.db.tags,
    { Name = "${var.name_prefix}-replica-${count.index}" }
  )

  # Ensure replicas depend on the primary DB instance
  depends_on = [aws_db_instance.db]
}
