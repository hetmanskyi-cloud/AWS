locals {
  # CIDR blocks
  public_subnet_cidr_blocks = [
    module.vpc.public_subnet_cidr_block_1,
    module.vpc.public_subnet_cidr_block_2,
    module.vpc.public_subnet_cidr_block_3
  ]
  private_subnet_cidr_blocks = [
    module.vpc.private_subnet_cidr_block_1,
    module.vpc.private_subnet_cidr_block_2,
    module.vpc.private_subnet_cidr_block_3
  ]

  # Individual subnet IDs
  public_subnet_id_1  = module.vpc.public_subnet_1_id
  public_subnet_id_2  = module.vpc.public_subnet_2_id
  public_subnet_id_3  = module.vpc.public_subnet_3_id
  private_subnet_id_1 = module.vpc.private_subnet_1_id
  private_subnet_id_2 = module.vpc.private_subnet_2_id
  private_subnet_id_3 = module.vpc.private_subnet_3_id

  # Lists of subnet IDs
  public_subnet_ids = [
    local.public_subnet_id_1,
    local.public_subnet_id_2,
    local.public_subnet_id_3
  ]
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
  kms_key_arn                 = module.kms.kms_key_arn
  flow_logs_retention_in_days = var.flow_logs_retention_in_days

  # General environment and naming configurations
  environment = var.environment
  name_prefix = var.name_prefix

  # SSH Access configuration
  enable_vpc_ssh_access = var.enable_vpc_ssh_access
  ssh_allowed_cidr      = var.ssh_allowed_cidr

  enable_public_nacl_http  = var.enable_public_nacl_http
  enable_public_nacl_https = var.enable_public_nacl_https
}

# --- KMS Module Configuration --- #
# Configures the KMS module for encryption and management of resources such as CloudWatch Logs, S3, and others.
module "kms" {
  source = "./modules/kms" # Path to the KMS module

  # AWS region and account-specific details
  aws_region     = var.aws_region     # Region where resources are created
  aws_account_id = var.aws_account_id # Account ID for KMS key permissions

  # Environment and naming
  environment = var.environment # Environment (e.g., dev, stage, prod)
  name_prefix = var.name_prefix # Prefix for naming resources

  # Additional principals for KMS key access
  additional_principals = var.additional_principals # List of ARNs for additional IAM roles or services

  # Key rotation and monitoring
  enable_key_rotation   = var.enable_key_rotation   # Enable automatic key rotation
  enable_kms_role       = var.enable_kms_role       # Create IAM role for managing the KMS key
  enable_key_monitoring = var.enable_key_monitoring # Enable CloudWatch Alarms for KMS key usage
  key_decrypt_threshold = var.key_decrypt_threshold # Custom threshold for Decrypt operations

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn # ARN of the SNS topic to send alarm notifications

  # Feature-specific flags for permissions
  enable_dynamodb    = var.enable_dynamodb    # Enable KMS permissions for DynamoDB
  enable_lambda      = var.enable_lambda      # Enable KMS permissions for Lambda
  enable_firehose    = var.enable_firehose    # Enable KMS permissions for Kinesis Firehose
  enable_waf_logging = var.enable_waf_logging # Enable KMS permissions for WAF logging

  # S3 buckets for KMS permissions
  buckets = var.buckets
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
  enable_dynamodb                   = var.enable_dynamodb
  enable_lambda                     = var.enable_lambda
  lambda_log_retention_days         = var.lambda_log_retention_days
  enable_cors                       = var.enable_cors
  allowed_origins                   = var.allowed_origins
  enable_s3_replication             = var.enable_s3_replication

  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn

  # KMS role for S3 module
  kms_key_arn = module.kms.kms_key_arn

  # Pass buckets list dynamically
  buckets = var.buckets

  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnets
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks

  # Pass providers explicitly
  providers = {
    aws             = aws
    aws.replication = aws.replication
  }

  depends_on = [module.endpoints]
}

# --- ASG Module Configuration --- #
module "asg" {
  source = "./modules/asg" # Path to module ASG

  # General naming and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment

  kms_key_arn = module.kms.kms_key_arn

  enable_s3_script = var.enable_s3_script

  enable_public_ip      = var.enable_public_ip
  enable_asg_ssh_access = var.enable_asg_ssh_access
  ssh_key_name          = var.ssh_key_name
  ssh_allowed_cidr      = var.ssh_allowed_cidr

  # ASG instance configuration
  ami_id                  = var.ami_id
  instance_type           = var.instance_type
  autoscaling_min         = var.autoscaling_min
  autoscaling_max         = var.autoscaling_max
  desired_capacity        = var.desired_capacity
  enable_scaling_policies = var.enable_scaling_policies
  enable_data_source      = var.enable_data_source
  scale_out_cpu_threshold = var.scale_out_cpu_threshold
  scale_in_cpu_threshold  = var.scale_in_cpu_threshold
  network_in_threshold    = var.network_in_threshold
  network_out_threshold   = var.network_out_threshold

  enable_scale_out_alarm        = var.enable_scale_out_alarm
  enable_scale_in_alarm         = var.enable_scale_in_alarm
  enable_asg_status_check_alarm = var.enable_asg_status_check_alarm
  enable_high_network_in_alarm  = var.enable_high_network_in_alarm
  enable_high_network_out_alarm = var.enable_high_network_out_alarm

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn

  # EBS volume configuration
  volume_size           = var.volume_size
  volume_type           = var.volume_type
  enable_ebs_encryption = var.enable_ebs_encryption

  # Networking and security configurations
  public_subnet_ids       = module.vpc.public_subnets
  alb_security_group_id   = module.alb.alb_security_group_id
  rds_security_group_id   = module.rds.rds_security_group_id
  redis_security_group_id = module.elasticache.redis_security_group_id
  vpc_id                  = module.vpc.vpc_id

  # ALB Target Group ARN for routing traffic to ASG instances
  wordpress_tg_arn = module.alb.wordpress_tg_arn

  # ALB Listener configuration
  enable_https_listener = module.alb.enable_https_listener

  # S3 bucket configurations
  buckets                    = var.buckets
  wordpress_media_bucket_arn = module.s3.wordpress_media_bucket_arn
  scripts_bucket_name        = module.s3.scripts_bucket_name
  scripts_bucket_arn         = module.s3.scripts_bucket_arn

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
  redis_port     = var.redis_port

  # WordPress Configuration
  wp_title          = var.wp_title
  wp_admin          = var.wp_admin
  wp_admin_email    = var.wp_admin_email
  wp_admin_password = var.wp_admin_password
  alb_dns_name      = module.alb.alb_dns_name

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
  vpc_cidr_block             = module.vpc.vpc_cidr_block
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks
  public_subnet_cidr_blocks  = local.public_subnet_cidr_blocks

  # Security group for RDS access (if needed in other modules)
  asg_security_group_id = module.asg.asg_security_group_id

  # Backup and replication settings
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  multi_az                     = var.multi_az
  performance_insights_enabled = var.performance_insights_enabled

  deletion_protection   = var.enable_deletion_protection
  skip_final_snapshot   = var.skip_final_snapshot
  enable_rds_monitoring = var.enable_rds_monitoring

  # RDS Alarm Thresholds
  rds_cpu_threshold_high    = var.rds_cpu_threshold_high
  rds_storage_threshold     = var.rds_storage_threshold
  rds_connections_threshold = var.rds_connections_threshold

  enable_low_storage_alarm      = var.enable_low_storage_alarm
  enable_high_cpu_alarm         = var.enable_high_cpu_alarm
  enable_high_connections_alarm = var.enable_high_connections_alarm

  # Logging configuration
  rds_log_retention_days = var.rds_log_retention_days

  # Read Replica Configuration
  read_replicas_count = var.read_replicas_count

  # KMS key for encryption
  kms_key_arn = module.kms.kms_key_arn

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn

  depends_on = [module.vpc]
}

# --- Endpoints Module Configuration --- #
module "endpoints" {
  source = "./modules/endpoints" # Path to module Endpoints

  aws_region                           = var.aws_region
  aws_account_id                       = var.aws_account_id
  name_prefix                          = var.name_prefix
  environment                          = var.environment
  vpc_id                               = module.vpc.vpc_id
  vpc_cidr_block                       = module.vpc.vpc_cidr_block
  kms_key_arn                          = module.kms.kms_key_arn
  private_subnet_ids                   = local.private_subnet_ids
  private_subnet_cidr_blocks           = local.private_subnet_cidr_blocks
  public_subnet_ids                    = local.public_subnet_ids
  public_subnet_cidr_blocks            = local.public_subnet_cidr_blocks
  enable_cloudwatch_logs_for_endpoints = var.enable_cloudwatch_logs_for_endpoints
  endpoints_log_retention_in_days      = var.endpoints_log_retention_in_days
}

# --- Elasticache Module Configuration --- #
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
  enable_failover          = var.enable_failover
  redis_port               = var.redis_port
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window

  # Networking (from VPC module)
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = local.private_subnet_ids

  # Security Group (from ASG module)
  asg_security_group_id = module.asg.asg_security_group_id

  # Monitoring
  redis_cpu_threshold                  = var.redis_cpu_threshold
  redis_memory_threshold               = var.redis_memory_threshold
  enable_redis_low_memory_alarm        = var.enable_redis_low_memory_alarm
  enable_redis_high_cpu_alarm          = var.enable_redis_high_cpu_alarm
  enable_redis_evictions_alarm         = var.enable_redis_evictions_alarm
  enable_redis_replication_bytes_alarm = var.enable_redis_replication_bytes_alarm
  redis_replication_bytes_threshold    = var.redis_replication_bytes_threshold
  enable_redis_low_cpu_credits_alarm   = var.enable_redis_low_cpu_credits_alarm
  redis_evictions_threshold            = var.redis_evictions_threshold
  redis_cpu_credits_threshold          = var.redis_cpu_credits_threshold

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms.arn
}

# --- ALB Module --- #
module "alb" {
  source = "./modules/alb"

  name_prefix        = var.name_prefix
  environment        = var.environment
  kms_key_arn        = module.kms.kms_key_arn
  public_subnets     = module.vpc.public_subnets
  logging_bucket     = module.s3.logging_bucket_id
  logging_bucket_arn = module.s3.logging_bucket_arn
  vpc_id             = module.vpc.vpc_id
  sns_topic_arn      = aws_sns_topic.cloudwatch_alarms.arn

  alb_enable_deletion_protection    = var.alb_enable_deletion_protection
  enable_https_listener             = var.enable_https_listener
  enable_alb_access_logs            = var.enable_alb_access_logs
  enable_high_request_alarm         = var.enable_high_request_alarm
  enable_5xx_alarm                  = var.enable_5xx_alarm
  enable_target_response_time_alarm = var.enable_target_response_time_alarm
  enable_health_check_failed_alarm  = var.enable_health_check_failed_alarm
  enable_waf                        = var.enable_waf
  enable_waf_logging                = var.enable_waf_logging
  enable_firehose                   = var.enable_firehose

  depends_on = [module.vpc, module.s3]
}