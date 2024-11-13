# --- RDS Database Instance Configuration --- #

# Define the RDS database instance with engine configurations and security settings
resource "aws_db_instance" "db" {
  identifier        = "${var.name_prefix}-db-${var.environment}" # Unique identifier for the RDS instance
  allocated_storage = var.allocated_storage                      # Storage size in GB
  instance_class    = var.instance_class                         # RDS instance class
  engine            = var.engine                                 # Database engine (e.g., "mysql")
  engine_version    = var.engine_version                         # Database engine version
  username          = var.username                               # Master username
  password          = var.password                               # Master password (sensitive)
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

  # Deletion Protection
  deletion_protection = var.deletion_protection # Enable or disable deletion protection

  # Final Snapshot Configuration
  skip_final_snapshot       = var.skip_final_snapshot                                # Skip final snapshot on deletion
  final_snapshot_identifier = "${var.name_prefix}-final-snapshot-${var.environment}" # Final snapshot name
  delete_automated_backups  = true                                                   # Delete automated backups when the instance is deleted

  # Performance Insights
  performance_insights_enabled    = false # Disable Performance Insights
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null


  # Monitoring
  monitoring_interval = var.enable_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_monitoring ? aws_iam_role.rds_monitoring_role.arn : null

  # Tags for resource identification
  tags = {
    Name        = "${var.name_prefix}-db-${var.environment}" # Resource name tag
    Environment = var.environment                            # Environment tag
  }

  # Depends on the creation of the security group
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
