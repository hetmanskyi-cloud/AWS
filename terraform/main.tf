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

  # List of all public subnet IDs
  public_subnet_ids = [
    local.public_subnet_id_1,
    local.public_subnet_id_2,
    local.public_subnet_id_3
  ]

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

  # General configurations
  name_prefix = var.name_prefix
  environment = var.environment
  aws_region  = var.aws_region
}

# --- VPC Module Configuration --- #
module "vpc" {
  source = "./modules/vpc"

  # CIDR and subnet configurations
  vpc_cidr_block              = var.vpc_cidr_block
  public_subnet_cidr_block_1  = var.public_subnet_cidr_block_1
  public_subnet_cidr_block_2  = var.public_subnet_cidr_block_2
  public_subnet_cidr_block_3  = var.public_subnet_cidr_block_3
  private_subnet_cidr_block_1 = var.private_subnet_cidr_block_1
  private_subnet_cidr_block_2 = var.private_subnet_cidr_block_2
  private_subnet_cidr_block_3 = var.private_subnet_cidr_block_3

  # Availability Zones for subnets
  availability_zone_public_1  = var.availability_zone_public_1
  availability_zone_public_2  = var.availability_zone_public_2
  availability_zone_public_3  = var.availability_zone_public_3
  availability_zone_private_1 = var.availability_zone_private_1
  availability_zone_private_2 = var.availability_zone_private_2
  availability_zone_private_3 = var.availability_zone_private_3

  # AWS region and account settings
  aws_region     = local.aws_region
  aws_account_id = var.aws_account_id

  # Security and logging configurations
  kms_key_arn           = module.kms.kms_key_arn
  log_retention_in_days = var.log_retention_in_days

  # General environment and naming configurations
  environment = local.environment
  name_prefix = local.name_prefix

  # SSH Access configuration
  enable_ssh_access = var.enable_ssh_access
}

# --- KMS Module Configuration --- #
module "kms" {
  source              = "./modules/kms"
  aws_region          = local.aws_region
  aws_account_id      = var.aws_account_id
  environment         = local.environment
  name_prefix         = local.name_prefix
  enable_key_rotation = var.enable_key_rotation
}

# --- EC2 Module Configuration --- #
module "ec2" {
  source = "./modules/ec2"

  # General naming and environment configuration
  name_prefix = local.name_prefix
  environment = local.environment

  # EC2 instance configuration
  ami_id                  = var.ami_id
  instance_type           = var.instance_type
  ssh_key_name            = var.ssh_key_name
  autoscaling_desired     = var.autoscaling_desired
  autoscaling_min         = var.autoscaling_min
  autoscaling_max         = var.autoscaling_max
  scale_out_cpu_threshold = var.scale_out_cpu_threshold
  scale_in_cpu_threshold  = var.scale_in_cpu_threshold

  # EBS volume configuration
  volume_size = var.volume_size
  volume_type = var.volume_type

  # Networking and security configurations
  public_subnet_id_1 = local.public_subnet_id_1
  public_subnet_id_2 = local.public_subnet_id_2
  public_subnet_id_3 = local.public_subnet_id_3
  enable_ssh_access  = var.enable_ssh_access
  security_group_id  = [module.ec2.ec2_security_group_id, module.rds.rds_security_group_id]
  vpc_id             = module.vpc.vpc_id

  # Pass RDS host and endpoint for WordPress configuration
  db_host     = module.rds.db_host
  db_endpoint = module.rds.db_endpoint

  # User data for initial setup (e.g., WordPress configuration)
  user_data = filebase64(var.user_data)
}

# --- RDS Module Configuration --- #
module "rds" {
  source      = "./modules/rds"
  name_prefix = local.name_prefix
  environment = local.environment

  # Database configuration
  allocated_storage = var.allocated_storage
  instance_class    = var.instance_class
  engine            = var.engine
  engine_version    = var.engine_version
  username          = var.db_username
  password          = var.db_password
  db_name           = var.db_name
  db_port           = var.db_port

  # Network configuration for private subnets
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks

  # Security group for RDS access (if needed in other modules)
  rds_security_group_id = [module.rds.rds_security_group_id]

  # Backup and replication settings
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  multi_az                = var.multi_az
  deletion_protection     = var.enable_deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  enable_monitoring       = var.enable_monitoring

  # KMS key for encryption
  kms_key_arn = module.kms.kms_key_arn
}

# --- Endpoints Module Configuration ---
module "endpoints" {
  source = "./modules/endpoints"

  # VPC configuration for endpoints
  vpc_id     = module.vpc.vpc_id
  aws_region = local.aws_region

  # Subnet configuration for interface endpoints
  private_subnet_ids = local.private_subnet_ids

  # Route table configuration for gateway endpoints (e.g., S3)
  route_table_ids = [module.vpc.private_route_table_id]

  # Security group for interface endpoints created in the endpoints module
  endpoint_sg_id = module.endpoints.endpoint_security_group_id

  # CIDR blocks of private subnets for security group rules
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks

  # Tagging and naming
  name_prefix = local.name_prefix
  environment = local.environment
}
