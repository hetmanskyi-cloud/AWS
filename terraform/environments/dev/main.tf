# --- VPC Module Configuration --- #
# Configures the Virtual Private Cloud (VPC) module to define the network infrastructure.
module "vpc" {
  source = "../../modules/vpc" # Path to module VPC

  # CIDR and subnet configurations
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true

  # AWS region and account settings
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  # Security and logging configurations
  kms_key_arn                 = module.kms.kms_key_arn
  flow_logs_retention_in_days = var.flow_logs_retention_in_days

  # SNS Topic for VPC Flow Logs Alarm Notifications
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  # Environment, tags and naming conventions
  environment = var.environment                          # Environment (e.g., dev, stage, prod)
  name_prefix = var.name_prefix                          # Prefix for naming resources
  tags        = merge(local.common_tags, local.tags_vpc) # Tags for resources

  depends_on = [module.kms]
}

# --- KMS Module Configuration --- #
# Configures the KMS module for encryption and management of resources such as CloudWatch Logs, S3, and others.
module "kms" {
  source = "../../modules/kms" # Path to the KMS module

  # AWS region and account-specific details
  aws_region         = var.aws_region         # Region for KMS operations
  replication_region = var.replication_region # Region for replication
  aws_account_id     = var.aws_account_id     # Account ID for KMS key permissions

  # Environment, tags and naming conventions
  environment = var.environment                          # Environment (e.g., dev, stage, prod)
  name_prefix = var.name_prefix                          # Prefix for naming resources
  tags        = merge(local.common_tags, local.tags_kms) # Tags for resources

  # Key rotation and monitoring
  enable_key_rotation            = var.enable_key_rotation            # Enable automatic key rotation
  kms_root_access                = var.kms_root_access                # Enable or disable root access in key policy
  enable_kms_admin_role          = var.enable_kms_admin_role          # Create IAM role for managing the KMS key
  enable_key_monitoring          = var.enable_key_monitoring          # Enable CloudWatch alarm for high KMS Decrypt usage
  enable_kms_access_denied_alarm = var.enable_kms_access_denied_alarm # Enable CloudWatch alarm for AccessDenied KMS errors
  key_decrypt_threshold          = var.key_decrypt_threshold          # Custom threshold for Decrypt operations (default: 100)

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn # ARN of the SNS topic to send alarm notifications

  # Feature-specific flags for permissions
  enable_dynamodb            = var.enable_dynamodb            # Enable KMS permissions for DynamoDB
  enable_alb_firehose        = var.enable_alb_firehose        # Enable KMS permissions for Kinesis ALB Firehose
  enable_alb_waf_logging     = var.enable_alb_waf_logging     # Enable KMS permissions for ALB WAF logging
  enable_cloudfront_firehose = var.enable_cloudfront_firehose # Enable KMS permissions for CloudFront Firehose
  enable_cloudfront_waf      = var.enable_cloudfront_waf      # Enable KMS permissions for CloudFront WAF

  # CloudFront Logging Settings
  enable_cloudfront_standard_logging_v2 = var.enable_cloudfront_standard_logging_v2 # Enable CloudFront standard logging v2

  # Pass the master switch to the KMS module to conditionally add SQS permissions
  enable_image_processor = var.enable_image_processor

  # S3 buckets for KMS permissions
  default_region_buckets     = var.default_region_buckets
  replication_region_buckets = var.replication_region_buckets
}

# --- ASG Module Configuration --- #
# Configures the Auto Scaling Group module for managing the application instances.
module "asg" {
  source = "../../modules/asg" # Path to module ASG

  # General naming, tags and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment
  aws_region  = var.aws_region
  tags        = merge(local.common_tags, local.tags_asg)

  # KMS key ARN for encrypting EBS volumes and other resources
  kms_key_arn = module.kms.kms_key_arn

  # ASG instance configuration
  ami_id                     = var.ami_id
  instance_type              = var.instance_type
  autoscaling_min            = var.autoscaling_min
  autoscaling_max            = var.autoscaling_max
  desired_capacity           = var.desired_capacity
  health_check_grace_period  = var.health_check_grace_period
  enable_scaling_policies    = var.enable_scaling_policies
  enable_target_tracking     = var.enable_target_tracking
  enable_data_source         = var.enable_data_source
  enable_interface_endpoints = var.enable_interface_endpoints
  scale_out_cpu_threshold    = var.scale_out_cpu_threshold
  scale_in_cpu_threshold     = var.scale_in_cpu_threshold
  network_in_threshold       = var.network_in_threshold
  network_out_threshold      = var.network_out_threshold

  # CloudWatch Alarms for Auto Scaling and instance health monitoring
  # Includes CPU utilization, network traffic, and EC2 status checks
  enable_scale_out_alarm        = var.enable_scale_out_alarm
  enable_scale_in_alarm         = var.enable_scale_in_alarm
  enable_asg_status_check_alarm = var.enable_asg_status_check_alarm
  enable_high_network_in_alarm  = var.enable_high_network_in_alarm
  enable_high_network_out_alarm = var.enable_high_network_out_alarm

  # CloudWatch Log Groups
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  cloudwatch_log_groups = var.enable_cloudwatch_logs ? {
    user_data = aws_cloudwatch_log_group.user_data_logs[0].name
    system    = aws_cloudwatch_log_group.system_logs[0].name
    nginx     = aws_cloudwatch_log_group.nginx_logs[0].name
    php_fpm   = aws_cloudwatch_log_group.php_fpm_logs[0].name
    wordpress = aws_cloudwatch_log_group.wordpress_logs[0].name
    } : {
    user_data = ""
    system    = ""
    nginx     = ""
    php_fpm   = ""
    wordpress = ""
  }

  # SNS Topic for CloudWatch Alarms
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  # EBS volume configuration
  volume_size           = var.volume_size
  volume_type           = var.volume_type
  enable_ebs_encryption = var.enable_ebs_encryption

  # EFS configuration
  efs_file_system_id  = var.enable_efs ? module.efs[0].efs_id : ""
  efs_access_point_id = var.enable_efs ? module.efs[0].efs_access_point_id : ""

  # Networking and security configurations
  subnet_ids                     = module.vpc.private_subnet_ids
  alb_security_group_id          = module.alb.alb_security_group_id
  vpc_endpoint_security_group_id = module.interface_endpoints.endpoint_security_group_id
  vpc_id                         = module.vpc.vpc_id

  # ALB Target Group ARN for routing traffic to ASG instances
  wordpress_tg_arn = module.alb.wordpress_tg_arn

  # ALB Listener configuration
  enable_https_listener = module.alb.enable_https_listener

  # S3 bucket configurations for scripts and media
  default_region_buckets     = var.default_region_buckets
  wordpress_media_bucket_arn = module.s3.wordpress_media_bucket_arn
  scripts_bucket_name        = module.s3.scripts_bucket_name
  scripts_bucket_arn         = module.s3.scripts_bucket_arn

  # Database Configuration (non-sensitive)
  db_host = module.rds.db_host

  # WordPress Configuration
  db_port           = var.db_port
  wp_title          = var.wp_title
  alb_dns_name      = module.alb.alb_dns_name
  php_version       = var.php_version
  redis_endpoint    = module.elasticache.redis_endpoint
  redis_port        = var.redis_port
  wordpress_version = var.wordpress_version

  # Determine the canonical public URL for WordPress in a specific priority order:
  # 1. Custom Domain: If a custom domain and SSL are enabled.
  # 2. CloudFront Domain: If accessed via CloudFront (default mode).
  # 3. ALB Domain: As a fallback for direct ALB access (dev/test mode).
  public_site_url = var.create_dns_and_ssl ? "https://${var.custom_domain_name}" : (
    var.wordpress_media_cloudfront_enabled && length(module.cloudfront) > 0 ?
    "https://${module.cloudfront[0].cloudfront_distribution_domain_name}" :
    "http://${module.alb.alb_dns_name}"
  )

  # Script path for deployment
  deploy_script_path = "${path.root}/../../scripts/deploy_wordpress.sh"

  # Pass the deployment toggle to the ASG module
  use_ansible_deployment = var.use_ansible_deployment

  # Secrets Configuration
  wordpress_secrets_name = aws_secretsmanager_secret.wp_secrets.name
  wordpress_secrets_arn  = aws_secretsmanager_secret.wp_secrets.arn
  rds_secrets_name       = var.rds_secret_name
  rds_secrets_arn        = aws_secretsmanager_secret.rds_secrets.arn
  redis_auth_secret_arn  = aws_secretsmanager_secret.redis_auth.arn
  redis_auth_secret_name = aws_secretsmanager_secret.redis_auth.name

  # Client VPN Configuration
  client_vpn_client_cidr_blocks = var.client_vpn_client_cidr_blocks
  enable_client_vpn             = var.enable_client_vpn

  depends_on = [module.vpc, module.kms,
    aws_secretsmanager_secret_version.wp_secrets_version,
    aws_cloudwatch_log_group.user_data_logs,
    aws_cloudwatch_log_group.system_logs,
    aws_cloudwatch_log_group.nginx_logs,
    aws_cloudwatch_log_group.php_fpm_logs,
    aws_cloudwatch_log_group.wordpress_logs
  ]
}

# --- RDS Module Configuration --- #
# Configures the Relational Database Service (RDS) module for the WordPress application.
module "rds" {
  source = "../../modules/rds" # Path to module RDS

  # General naming, tags and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_rds)

  # Database configuration
  allocated_storage = var.allocated_storage
  instance_class    = var.instance_class
  engine            = var.engine
  engine_version    = var.engine_version
  db_username       = var.db_username
  db_password       = random_password.db_password.result
  db_name           = var.db_name
  db_port           = var.db_port

  # Network configuration for private subnets
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security group for RDS access (if needed in other modules)
  asg_security_group_id = module.asg.asg_security_group_id

  # Backup and replication settings
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  multi_az                     = var.multi_az
  performance_insights_enabled = var.performance_insights_enabled

  rds_deletion_protection = var.rds_deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  enable_rds_monitoring   = var.enable_rds_monitoring

  # RDS Alarm Thresholds
  # Note: Fine-tune these thresholds based on expected workload and performance requirements
  rds_cpu_threshold_high    = var.rds_cpu_threshold_high
  rds_storage_threshold     = var.rds_storage_threshold
  rds_connections_threshold = var.rds_connections_threshold

  # CloudWatch Alarms for RDS performance and availability
  enable_low_storage_alarm      = var.enable_low_storage_alarm
  enable_high_cpu_alarm         = var.enable_high_cpu_alarm
  enable_high_connections_alarm = var.enable_high_connections_alarm

  # Logging configuration
  rds_log_retention_days = var.rds_log_retention_days

  # Read Replica Configuration
  read_replicas_count = var.read_replicas_count

  # KMS key for encryption of RDS data
  kms_key_arn = module.kms.kms_key_arn

  # SNS Topic for CloudWatch Alarms notifications
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  depends_on = [module.vpc]
}

# --- S3 Module Configuration --- #
# - Manages S3 buckets for application media, logs, scripts, and replication
# - Ensures proper encryption, versioning, and access controls
module "s3" {
  source = "../../modules/s3" # Path to S3 module

  # Providers
  providers = {
    aws             = aws.default
    aws.replication = aws.replication
  }

  # S3 configuration
  aws_region                        = var.aws_region
  aws_account_id                    = var.aws_account_id
  environment                       = var.environment
  name_prefix                       = var.name_prefix
  noncurrent_version_retention_days = var.noncurrent_version_retention_days
  enable_dynamodb                   = var.enable_dynamodb
  enable_cors                       = var.enable_cors
  allowed_origins                   = var.allowed_origins
  s3_scripts                        = var.s3_scripts
  tags                              = merge(local.common_tags, local.tags_s3)

  # SNS Topic for CloudWatch Alarms notifications
  sns_topic_arn                    = aws_sns_topic.cloudwatch_alarms_topic.arn
  replication_region_sns_topic_arn = try(aws_sns_topic.replication_region_notifications_topic[0].arn, null)

  # KMS role for S3 module
  kms_key_arn         = module.kms.kms_key_arn
  kms_replica_key_arn = module.kms.kms_replica_key_arn

  # Pass buckets list dynamically
  default_region_buckets     = var.default_region_buckets
  replication_region_buckets = var.replication_region_buckets

  # CloudFront Integration
  wordpress_media_cloudfront_distribution_arn = length(module.cloudfront) > 0 ? module.cloudfront[0].cloudfront_distribution_arn : null
  wordpress_media_cloudfront_enabled          = var.wordpress_media_cloudfront_enabled
  enable_cloudfront_standard_logging_v2       = var.enable_cloudfront_standard_logging_v2

  depends_on = [
    aws_sns_topic.cloudwatch_alarms_topic
  ]
}

# --- Elasticache Module Configuration --- #
# Configures the ElastiCache module for managing the Redis caching layer.
module "elasticache" {
  source = "../../modules/elasticache" # Path to module Elasticache

  # General naming, tags and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_redis)

  # KMS key ARN for encrypting data at rest in ElastiCache
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
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security Group (from ASG module)
  asg_security_group_id = module.asg.asg_security_group_id

  # Monitoring thresholds for Redis cluster
  redis_cpu_threshold                  = var.redis_cpu_threshold
  redis_memory_threshold               = var.redis_memory_threshold
  enable_redis_low_memory_alarm        = var.enable_redis_low_memory_alarm
  enable_redis_high_cpu_alarm          = var.enable_redis_high_cpu_alarm
  enable_redis_replication_bytes_alarm = var.enable_redis_replication_bytes_alarm
  redis_replication_bytes_threshold    = var.redis_replication_bytes_threshold
  enable_redis_low_cpu_credits_alarm   = var.enable_redis_low_cpu_credits_alarm
  redis_cpu_credits_threshold          = var.redis_cpu_credits_threshold

  # Secrets Configuration
  redis_auth_token = random_password.redis_auth_token.result

  # SNS Topic for CloudWatch Alarms notifications
  sns_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  depends_on = [
    module.vpc,
    module.kms
  ]
}

# --- ALB Module --- #
# Configures the Application Load Balancer (ALB) for routing traffic to the application instances.
module "alb" {
  source = "../../modules/alb"

  # AWS region, tags and account settings
  tags                                = merge(local.common_tags, local.tags_alb)
  name_prefix                         = var.name_prefix
  environment                         = var.environment
  public_subnets                      = module.vpc.public_subnet_ids
  alb_logs_bucket_name                = module.s3.alb_logs_bucket_name
  logging_bucket_arn                  = module.s3.logging_bucket_arn
  vpc_id                              = module.vpc.vpc_id
  vpc_cidr_block                      = module.vpc.vpc_cidr_block
  kms_key_arn                         = module.kms.kms_key_arn
  sns_topic_arn                       = aws_sns_topic.cloudwatch_alarms_topic.arn
  alb_enable_deletion_protection      = var.alb_enable_deletion_protection
  enable_https_listener               = var.enable_https_listener
  enable_alb_access_logs              = var.enable_alb_access_logs
  enable_high_request_alarm           = var.enable_high_request_alarm
  enable_5xx_alarm                    = var.enable_5xx_alarm
  enable_target_response_time_alarm   = var.enable_target_response_time_alarm
  enable_alb_waf                      = var.enable_alb_waf
  enable_alb_waf_logging              = var.enable_alb_waf_logging
  enable_alb_firehose                 = var.enable_alb_firehose
  enable_alb_firehose_cloudwatch_logs = var.enable_alb_firehose_cloudwatch_logs

  # ASG Security Group
  asg_security_group_id = module.asg.asg_security_group_id

  # CloudFront to ALB integration
  cloudfront_to_alb_secret_header_value = random_password.cloudfront_to_alb_header.result
  alb_access_cloudfront_mode            = var.wordpress_media_cloudfront_enabled

  depends_on = [module.vpc, aws_sns_topic.cloudwatch_alarms_topic]
}

# --- Interface Endpoints Module Configuration (Now disabled) --- #
# Configures the VPC Interface Endpoints for secure access to AWS services within the VPC.
module "interface_endpoints" {
  source = "../../modules/interface_endpoints" # Path to module Interface Endpoints

  aws_region                  = var.aws_region
  name_prefix                 = var.name_prefix
  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  vpc_cidr_block              = module.vpc.vpc_cidr_block
  private_subnet_ids          = module.vpc.private_subnet_ids
  enable_interface_endpoints  = var.enable_interface_endpoints
  interface_endpoint_services = var.interface_endpoint_services
  tags                        = merge(local.common_tags, local.tags_interface_endpoints)
}

# --- CloudFront Module Configuration --- #

# Configures the CloudFront CDN for WordPress media, including WAF and logging.
# This module must operate in us-east-1, hence specific variable requirements.
module "cloudfront" {
  count = var.wordpress_media_cloudfront_enabled && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  source = "../../modules/cloudfront" # Path to your CloudFront module

  # Providers block to specify which provider configuration to use for this module.
  providers = {
    aws            = aws.default    # Pass our root default provider to the child's default 'aws'
    aws.cloudfront = aws.cloudfront # Pass our root 'aws.cloudfront' provider (us-east-1) to the child's 'aws.cloudfront'
  }

  # Global Naming and Tagging
  aws_region  = var.aws_region
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_cloudfront)

  # CloudFront Distribution Settings
  wordpress_media_cloudfront_enabled = var.wordpress_media_cloudfront_enabled
  cloudfront_price_class             = var.cloudfront_price_class

  # Pass the entire map of bucket configurations. This allows the module to know
  # that the 'wordpress_media' bucket is indeed enabled.
  default_region_buckets = var.default_region_buckets

  # Dependencies from other modules (S3, KMS)
  # The `s3_module_outputs` variable in the CloudFront module expects an object
  # containing specific outputs from your S3 module.
  s3_module_outputs = {
    wordpress_media_bucket_regional_domain_name = module.s3.wordpress_media_bucket_regional_domain_name
    # Add any other relevant S3 bucket outputs here that CloudFront module might need
  }

  logging_bucket_arn  = module.s3.logging_bucket_arn  # Assuming your S3 module outputs a general logging bucket ARN
  logging_bucket_name = module.s3.logging_bucket_name # Name of the logging bucket
  kms_key_arn         = module.kms.kms_key_arn        # Pass the KMS key for logging encryption

  # WAF Integration Settings
  enable_cloudfront_waf = var.enable_cloudfront_waf

  # Kinesis Firehose for WAF Logging Settings
  enable_cloudfront_firehose = var.enable_cloudfront_firehose

  # CloudFront Access Logging v2 Settings
  enable_cloudfront_standard_logging_v2 = var.enable_cloudfront_standard_logging_v2

  # SNS Topic for CloudWatch Alarms notifications
  sns_alarm_topic_arn = var.enable_cloudfront_waf ? aws_sns_topic.cloudfront_alarms_topic[0].arn : null

  # CloudFront to ALB integration
  cloudfront_to_alb_secret_header_value = random_password.cloudfront_to_alb_header.result

  # ALB DNS Name (from ALB module)
  alb_dns_name = module.alb.alb_dns_name

  # Origin Shield Settings
  enable_origin_shield = var.enable_origin_shield

  # Custom Domain and ACM Integration
  # This conditionally passes the certificate ARN and domain names to the CloudFront module.
  acm_certificate_arn   = var.create_dns_and_ssl ? module.acm[0].acm_arn : null
  custom_domain_aliases = var.create_dns_and_ssl ? concat([var.custom_domain_name], var.subject_alternative_names) : []

  # Client VPN Settings
  enable_client_vpn = var.enable_client_vpn

  # Pass the list of IPs from external data source to the CloudFront module.
  # We use jsondecode to parse the JSON string returned by the script.
  vpn_egress_cidrs = var.enable_client_vpn && var.enable_cloudfront_waf ? jsondecode(data.external.vpn_egress_ips[0].result.public_ips_json) : []

  depends_on = [
    module.kms # CloudFront logging (Firehose/CloudWatch) may depend on KMS
  ]
}

# --- ACM Certificate Module --- #

# Requests an SSL certificate for the custom domain.
# This module is created only if a custom domain setup is enabled.
module "acm" {
  source = "../../modules/acm"
  count  = var.create_dns_and_ssl ? 1 : 0 # The master switch for this module

  # Providers block to specify which provider configuration to use for this module.
  providers = {
    aws            = aws.default    # Pass our root default provider to the child's default 'aws'
    aws.cloudfront = aws.cloudfront # Pass our root 'aws.cloudfront' provider (us-east-1) to the child's 'aws.cloudfront'
  }

  # Pass variables for naming and tagging
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_acm)

  # Certificate details
  custom_domain_name        = var.custom_domain_name
  subject_alternative_names = var.subject_alternative_names
}

# --- Route53 DNS Module --- #

# Manages the DNS Hosted Zone, validates the ACM certificate, and points the domain to CloudFront.
# This module is also created only if a custom domain setup is enabled.
module "route53" {
  source = "../../modules/route53"
  count  = var.create_dns_and_ssl ? 1 : 0 # The master switch for this module

  # Pass variables for naming and tagging
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_route53)

  # Domain details
  custom_domain_name        = var.custom_domain_name
  subject_alternative_names = var.subject_alternative_names

  # WIRING:

  # From ACM module
  acm_certificate_arn                       = module.acm[0].acm_arn
  acm_certificate_domain_validation_options = module.acm[0].domain_validation_options

  # From CloudFront module
  cloudfront_distribution_domain_name    = length(module.cloudfront) > 0 ? module.cloudfront[0].cloudfront_distribution_domain_name : null
  cloudfront_distribution_hosted_zone_id = length(module.cloudfront) > 0 ? module.cloudfront[0].cloudfront_distribution_hosted_zone_id : null
}

# --- Lambda Layer Module for Pillow --- #

# This module call instructs Terraform to build and deploy the Pillow dependency layer.
# It is created only if the image processing feature is enabled in terraform.tfvars.
module "lambda_layer" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  source = "../../modules/lambda_layer"

  # Pass variables for naming
  name_prefix = var.name_prefix
  environment = var.environment

  # Pass configuration from the variables file (`terraform.tfvars`)
  layer_name         = var.layer_name
  layer_runtime      = var.layer_runtime
  layer_architecture = var.layer_architecture
  library_version    = var.library_version

  # The source path is part of the project's structure
  source_path = "../../modules/lambda_images/src"
}

# --- SQS Queues for Image Processing --- #

# This module call creates the main queue and its Dead Letter Queue (DLQ).
# Its creation is controlled by the 'enable_image_processor' feature flag,
# ensuring it is only provisioned when the image processing feature is active.
module "sqs" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  source = "../../modules/sqs"

  # Naming and Tagging
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_sqs)

  # Configuration
  # Pass the entire map of queue definitions from the root variables.
  sqs_queues = var.sqs_queues

  # Monitoring
  cloudwatch_alarms_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  # Dependencies
  # Pass the KMS key ARN from the KMS module for queue encryption.
  kms_key_arn = module.kms.kms_key_arn

  # Explicitly state that this module depends on the KMS key being created first.
  depends_on = [module.kms]
}

# --- DynamoDB (Image Metadata) Module Configuration --- #

# This module call creates the DynamoDB table for storing image processing metadata.
# Its creation is controlled by the 'enable_image_processor' feature flag.
module "dynamodb" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  source = "../../modules/dynamodb"

  # Pass configuration from root variables
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_dynamodb)

  dynamodb_table_name                    = var.dynamodb_table_name
  dynamodb_provisioned_autoscaling       = var.dynamodb_provisioned_autoscaling
  dynamodb_table_class                   = var.dynamodb_table_class
  dynamodb_hash_key_name                 = var.dynamodb_hash_key_name
  dynamodb_hash_key_type                 = var.dynamodb_hash_key_type
  dynamodb_range_key_name                = var.dynamodb_range_key_name
  dynamodb_range_key_type                = var.dynamodb_range_key_type
  dynamodb_gsi                           = var.dynamodb_gsi
  enable_dynamodb_point_in_time_recovery = var.enable_dynamodb_point_in_time_recovery
  dynamodb_deletion_protection_enabled   = var.dynamodb_deletion_protection_enabled
  enable_dynamodb_ttl                    = var.enable_dynamodb_ttl
  dynamodb_ttl_attribute_name            = var.dynamodb_ttl_attribute_name

  # Wire dependencies from other modules
  # Pass the KMS key ARN from the KMS module for encryption.
  kms_key_arn = module.kms.kms_key_arn

  # Monitoring
  cloudwatch_alarms_topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn

  # Explicit Dependencies
  depends_on = [module.kms]
}

# --- Lambda Images (Processor) Module Configuration --- #

# This is the central module of the image processing pipeline.
# It creates the Lambda function, its IAM role, and the SQS trigger.
# Its creation is controlled by the main 'enable_image_processor' feature flag.

module "lambda_images" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  source = "../../modules/lambda_images"

  # Naming, Tagging, and Core Config
  aws_region           = var.aws_region
  aws_account_id       = var.aws_account_id
  name_prefix          = var.name_prefix
  environment          = var.environment
  tags                 = merge(local.common_tags, local.tags_lambda_images)
  lambda_function_name = var.lambda_function_name
  lambda_runtime       = var.lambda_runtime
  lambda_architecture  = [var.lambda_architecture] # Use a list as expected by the module
  lambda_memory_size   = var.lambda_memory_size
  lambda_timeout       = var.lambda_timeout
  sqs_batch_size       = var.sqs_batch_size

  # S3 Bucket Configuration
  source_s3_bucket_name = module.s3.wordpress_media_bucket_name
  source_s3_prefix      = var.wordpress_media_uploads_prefix
  destination_s3_prefix = var.lambda_destination_prefix

  # SQS Queues
  sqs_trigger_queue_arn = module.sqs[0].queue_arns["image-processing"]
  dead_letter_queue_arn = module.sqs[0].queue_arns["image-processing-dlq"]

  # DynamoDB Table
  dynamodb_table_arn  = module.dynamodb[0].dynamodb_table_arn
  dynamodb_table_name = module.dynamodb[0].dynamodb_table_name

  # Lambda Layer
  lambda_layers = [module.lambda_layer[0].layer_version_arn]

  # KMS Key for permissions
  kms_key_arn = module.kms.kms_key_arn

  # Monitoring and Permissions
  alarms_enabled                = var.enable_lambda_alarms
  sns_topic_arn                 = aws_sns_topic.cloudwatch_alarms_topic.arn
  lambda_iam_policy_attachments = var.lambda_iam_policy_attachments
  lambda_environment_variables  = var.lambda_environment_variables
  enable_lambda_tracing         = var.enable_lambda_tracing

  # Explicitly provide the path to the function's source code directory.
  lambda_source_code_path = "${path.module}/../../modules/lambda_images/src"

  # Explicitly define all dependencies for clarity and correct execution order.
  depends_on = [
    module.s3,
    module.sqs,
    module.dynamodb,
    module.lambda_layer,
    module.kms
  ]
}

# --- EFS Module Configuration --- #

# Configures the Elastic File System (EFS) for shared storage across ASG instances.
module "efs" {
  count = var.enable_efs ? 1 : 0

  source = "../../modules/efs" # Path to the EFS module

  # General naming, tags and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_efs) # Assuming you add local.tags_efs in metadata.tf

  # Network configuration
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  asg_security_group_id = module.asg.asg_security_group_id

  # Security and Encryption
  kms_key_arn = module.kms.kms_key_arn

  # Lifecycle Policy
  enable_efs_lifecycle_policy = var.enable_efs_lifecycle_policy
  transition_to_ia            = var.efs_transition_to_ia

  # Monitoring and Alarms
  sns_topic_arn             = aws_sns_topic.cloudwatch_alarms_topic.arn
  enable_burst_credit_alarm = var.enable_efs_burst_credit_alarm
  burst_credit_threshold    = var.efs_burst_credit_threshold

  # Access Point Configuration
  efs_access_point_path      = var.efs_access_point_path
  efs_access_point_posix_uid = var.efs_access_point_posix_uid
  efs_access_point_posix_gid = var.efs_access_point_posix_gid

  depends_on = [
    module.vpc,
    module.kms
  ]
}

# --- Client VPN Module Configuration --- #
# Deploys a self-contained Client VPN endpoint with certificate-based authentication.
# Creation is controlled by the 'enable_client_vpn' variable.

module "client_vpn" {
  count  = var.enable_client_vpn ? 1 : 0
  source = "../../modules/client_vpn"

  # General naming and tags from root
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = merge(local.common_tags, local.tags_client_vpn)

  # KMS Key for encryption
  kms_key_arn = module.kms.kms_key_arn

  # VPN Endpoint Configuration
  client_vpn_split_tunnel       = var.client_vpn_split_tunnel
  client_vpn_client_cidr_blocks = var.client_vpn_client_cidr_blocks

  # Logging Configuration
  client_vpn_log_retention_days = var.client_vpn_log_retention_days

  # VPC Integration
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr_block

  # Pass the VPC's DNS server address, derived from the VPC CIDR (from module output to avoid drift).
  custom_dns_servers = [cidrhost(module.vpc.vpc_cidr_block, 2)]

  # Pointing to public subnets
  vpc_subnet_ids = module.vpc.public_subnet_ids

  # Authentication settings
  authentication_type = var.client_vpn_authentication_type
  saml_provider_arn   = var.client_vpn_saml_provider_arn

  # Additional features
  enable_self_service_portal = var.client_vpn_enable_self_service_portal
  vpn_access_group_id        = var.client_vpn_access_group_id
}

# --- Notes and Recommendations --- #
# 1. All modules are interconnected and rely on shared variables and outputs.
# 2. Ensure that any changes in variables or outputs are reviewed across all dependent modules.
# 3. Validate configurations after updates to avoid runtime errors or broken dependencies.
