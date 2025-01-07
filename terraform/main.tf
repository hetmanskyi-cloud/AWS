locals {
  # CIDR blocks for public subnets
  public_subnet_cidr_blocks = [
    module.vpc.public_subnet_cidr_block_1,
    module.vpc.public_subnet_cidr_block_2,
    module.vpc.public_subnet_cidr_block_3
  ]

  # CIDR blocks for private subnets
  private_subnet_cidr_blocks = [
    module.vpc.private_subnet_cidr_block_1,
    module.vpc.private_subnet_cidr_block_2,
    module.vpc.private_subnet_cidr_block_3
  ]

  # Individual public subnet IDs
  public_subnet_id_1 = module.vpc.public_subnet_1_id
  public_subnet_id_2 = module.vpc.public_subnet_2_id
  public_subnet_id_3 = module.vpc.public_subnet_3_id

  # Individual private subnet IDs
  private_subnet_id_1 = module.vpc.private_subnet_1_id
  private_subnet_id_2 = module.vpc.private_subnet_2_id
  private_subnet_id_3 = module.vpc.private_subnet_3_id

  # List of all private subnet IDs
  private_subnet_ids = [
    local.private_subnet_id_1,
    local.private_subnet_id_2,
    local.private_subnet_id_3
  ]
}

# --- VPC Module Configuration --- #
module "vpc" {
  source = "./modules/vpc" # Path to module VPC

  # CIDR and subnet configurations
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_block_1 = var.public_subnet_cidr_block_1
  public_subnet_cidr_block_2 = var.public_subnet_cidr_block_2
  public_subnet_cidr_block_3 = var.public_subnet_cidr_block_3

  private_subnet_cidr_block_1 = var.private_subnet_cidr_block_1
  private_subnet_cidr_block_2 = var.private_subnet_cidr_block_2
  private_subnet_cidr_block_3 = var.private_subnet_cidr_block_3

  # Availability Zones for subnets
  availability_zone_public_1 = var.availability_zone_public_1
  availability_zone_public_2 = var.availability_zone_public_2
  availability_zone_public_3 = var.availability_zone_public_3

  availability_zone_private_1 = var.availability_zone_private_1
  availability_zone_private_2 = var.availability_zone_private_2
  availability_zone_private_3 = var.availability_zone_private_3

  # AWS region and account settings
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  # Security and logging configurations
  kms_key_arn           = module.kms.kms_key_arn
  log_retention_in_days = var.log_retention_in_days

  # General environment and naming configurations
  environment = var.environment
  name_prefix = var.name_prefix

  # SSH Access configuration
  enable_ssh_access = var.enable_ssh_access
}

# --- KMS Module Configuration --- #
module "kms" {
  source = "./modules/kms" # Path to module KMS

  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  environment           = var.environment
  name_prefix           = var.name_prefix
  additional_principals = var.additional_principals           # List of additional principals
  enable_key_rotation   = var.enable_key_rotation             # Enable automatic key rotation
  enable_kms_role       = var.enable_kms_role                 # Activate after initial setup KMS
  enable_key_monitoring = var.enable_key_monitoring           # Enable CloudWatch Alarms for KMS monitoring
  key_decrypt_threshold = var.key_decrypt_threshold           # Set a custom threshold for Decrypt operations, adjust as needed
  sns_topic_arn         = aws_sns_topic.cloudwatch_alarms.arn # SNS Topic for CloudWatch Alarms
}

# --- EC2 Module Configuration --- #
module "ec2" {
  source = "./modules/ec2" # Path to module EC2

  # General naming and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment

  # EC2 instance configuration
  ami_id                  = var.ami_id
  instance_type           = var.instance_type
  ssh_key_name            = var.ssh_key_name
  autoscaling_min         = var.autoscaling_min
  autoscaling_max         = var.autoscaling_max
  scale_out_cpu_threshold = var.scale_out_cpu_threshold
  scale_in_cpu_threshold  = var.scale_in_cpu_threshold
  network_in_threshold    = var.network_in_threshold
  network_out_threshold   = var.network_out_threshold

  # S3 bucket for storing AMI images
  ami_bucket_name = module.s3.ami_bucket_name

  # S3 bucket for storing scripts
  scripts_bucket_name = module.s3.scripts_bucket_name

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn

  # EBS volume configuration
  volume_size = var.volume_size
  volume_type = var.volume_type

  # Networking and security configurations
  public_subnet_ids = module.vpc.public_subnets
  enable_ssh_access = var.enable_ssh_access
  alb_sg_id         = module.alb.alb_sg_id
  security_group_id = [
    module.ec2.ec2_security_group_id,
    module.rds.rds_security_group_id,
    module.elasticache.redis_security_group_id,
    module.alb.alb_sg_id
  ]
  vpc_id = module.vpc.vpc_id

  # ALB Target Group ARN for routing traffic to EC2 instances
  target_group_arn = module.alb.wordpress_tg_arn

  # S3 bucket configurations
  wordpress_media_bucket_arn = module.s3.wordpress_media_bucket_arn
  scripts_bucket_arn         = module.s3.scripts_bucket_arn
  ami_bucket_arn             = module.s3.ami_bucket_arn

  # Pass RDS host and endpoint for WordPress configuration
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = var.db_password
  db_host         = module.rds.db_host
  db_endpoint     = module.rds.db_endpoint
  php_version     = var.php_version
  php_fpm_service = "php${var.php_version}-fpm"

  # Pass Redis host and endpoint for WordPress configuration
  redis_endpoint = module.elasticache.redis_endpoint
  redis_port     = module.elasticache.redis_port

  # User data for initial setup
  user_data = base64encode(templatefile("${path.root}/scripts/deploy_wordpress.sh", {
    DB_NAME         = var.db_name,
    DB_USERNAME     = var.db_username,
    DB_USER         = var.db_username,
    DB_PASSWORD     = var.db_password,
    DB_HOST         = module.rds.db_host,
    PHP_VERSION     = var.php_version,
    PHP_FPM_SERVICE = "php${var.php_version}-fpm",
    REDIS_HOST      = module.elasticache.redis_endpoint,
    REDIS_PORT      = var.redis_port
  }))

  depends_on = [module.vpc]
}

# --- RDS Module Configuration --- #
module "rds" {
  source = "./modules/rds" # Path to module RDS

  # General naming and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment

  # AWS region and account settings
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  # Database configuration
  allocated_storage = var.allocated_storage
  instance_class    = var.instance_class
  engine            = var.engine
  engine_version    = var.engine_version
  db_username       = var.db_username
  db_password       = var.db_password
  db_name           = var.db_name
  db_port           = var.db_port

  # Network configuration for private subnets
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks
  public_subnet_cidr_blocks  = local.public_subnet_cidr_blocks

  # Security group for RDS access (if needed in other modules)
  rds_security_group_id = [module.rds.rds_security_group_id]
  ec2_security_group_id = module.ec2.ec2_security_group_id

  # Backup and replication settings
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  multi_az                     = var.multi_az
  performance_insights_enabled = var.performance_insights_enabled

  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  enable_monitoring   = var.enable_monitoring

  # RDS Alarm Thresholds
  rds_cpu_threshold_high    = var.rds_cpu_threshold_high
  rds_storage_threshold     = var.rds_storage_threshold
  rds_connections_threshold = var.rds_connections_threshold

  # Read Replica Configuration
  read_replicas_count = var.read_replicas_count

  # RDS Instance Identifier
  db_instance_identifier = module.rds.db_instance_identifier

  # KMS key for encryption
  kms_key_arn = module.kms.kms_key_arn

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn
}

# --- Endpoints Module Configuration --- #
module "endpoints" {
  source = "./modules/endpoints" # Path to module Endpoints

  aws_region                           = var.aws_region
  aws_account_id                       = var.aws_account_id
  name_prefix                          = var.name_prefix
  environment                          = var.environment
  vpc_id                               = module.vpc.vpc_id
  kms_key_arn                          = module.kms.kms_key_arn
  private_subnet_ids                   = local.private_subnet_ids
  private_subnet_cidr_blocks           = local.private_subnet_cidr_blocks
  enable_cloudwatch_logs_for_endpoints = var.enable_cloudwatch_logs_for_endpoints
  endpoints_log_retention_in_days      = var.endpoints_log_retention_in_days
}

# --- S3 Module --- #
module "s3" {
  source = "./modules/s3" # Path to S3 module

  # S3 configuration
  replication_region                = var.replication_region
  aws_account_id                    = var.aws_account_id
  environment                       = var.environment
  name_prefix                       = var.name_prefix
  enable_versioning                 = var.enable_versioning
  noncurrent_version_retention_days = var.noncurrent_version_retention_days
  enable_terraform_state_bucket     = var.enable_terraform_state_bucket
  enable_wordpress_media_bucket     = var.enable_wordpress_media_bucket
  enable_cors                       = var.enable_cors
  enable_replication_bucket         = var.enable_replication_bucket
  enable_s3_replication             = var.enable_s3_replication
  enable_lambda                     = var.enable_lambda
  enable_dynamodb                   = var.enable_dynamodb
  sns_topic_arn                     = aws_sns_topic.cloudwatch_alarms.arn

  # KMS role for S3 module
  kms_key_arn = module.kms.kms_key_arn

  # Pass buckets list dynamically
  buckets = var.buckets

  # Pass providers explicitly
  providers = {
    aws             = aws
    aws.replication = aws.replication
  }
}

# --- Elasticache Module --- #
module "elasticache" {
  source = "./modules/elasticache" # Path to module Elasticache

  name_prefix = var.name_prefix
  environment = var.environment

  kms_key_arn = module.kms.kms_key_arn

  # ElastiCache configuration
  redis_version            = var.redis_version
  node_type                = var.node_type
  replicas_per_node_group  = var.replicas_per_node_group
  num_node_groups          = var.num_node_groups
  redis_port               = var.redis_port
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window

  # Networking (from VPC module)
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = local.private_subnet_ids

  # Security Group (from EC2 module)
  ec2_security_group_id = module.ec2.ec2_security_group_id

  # Monitoring
  redis_cpu_threshold                = var.redis_cpu_threshold
  redis_memory_threshold             = var.redis_memory_threshold
  enable_redis_low_memory_alarm      = var.enable_redis_low_memory_alarm
  enable_redis_high_cpu_alarm        = var.enable_redis_high_cpu_alarm
  enable_redis_low_cpu_credits_alarm = var.enable_redis_low_cpu_credits_alarm

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn
}

# --- ALB Module --- #
module "alb" {
  source             = "./modules/alb"
  name_prefix        = var.name_prefix
  environment        = var.environment
  kms_key_arn        = module.kms.kms_key_arn
  alb_name           = module.alb.alb_name
  public_subnets     = module.vpc.public_subnets
  logging_bucket     = module.s3.logging_bucket_id
  logging_bucket_arn = module.s3.logging_bucket_arn
  alb_sg_id          = module.alb.alb_sg_id
  vpc_id             = module.vpc.vpc_id
  sns_topic_arn      = aws_sns_topic.cloudwatch_alarms.arn

  alb_enable_deletion_protection = var.alb_enable_deletion_protection
  enable_https_listener          = var.enable_https_listener
  enable_alb_access_logs         = var.enable_alb_access_logs
  enable_high_request_alarm      = var.enable_high_request_alarm
  enable_5xx_alarm               = var.enable_5xx_alarm
  enable_waf                     = var.enable_waf
  enable_waf_logging             = var.enable_waf_logging
  enable_firehose                = var.enable_firehose

  depends_on = [module.vpc, module.s3]
}