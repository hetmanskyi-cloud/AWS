# --- VPC Module Configuration ---
# Configures VPC, subnets, route tables, NACLs, and flow logs.
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
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  # Security and logging configurations
  kms_key_arn           = module.kms.kms_key_arn # Dynamic encryption key
  log_retention_in_days = var.log_retention_in_days

  # General environment and naming configurations
  environment = var.environment
  name_prefix = var.name_prefix
}

# --- KMS Module Configuration ---
# Creates and manages a KMS key for encryption needs (CloudWatch Logs, S3, etc.)
module "kms" {
  source              = "./modules/kms"
  aws_region          = var.aws_region
  aws_account_id      = var.aws_account_id
  environment         = var.environment
  name_prefix         = var.name_prefix
  enable_key_rotation = var.enable_key_rotation
}

# --- EC2 Module Configuration ---
# Configures EC2 instances with auto-scaling and security settings, deployed across public subnets.
module "ec2" {
  source = "./modules/ec2"

  # General naming and environment configuration
  name_prefix = var.name_prefix
  environment = var.environment

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
  public_subnet_id_1 = module.vpc.public_subnet_1_id
  public_subnet_id_2 = module.vpc.public_subnet_2_id
  public_subnet_id_3 = module.vpc.public_subnet_3_id
  security_group_id  = [module.ec2.ec2_security_group_id]
  vpc_id             = module.vpc.vpc_id

  # User data for initial setup (e.g., WordPress configuration)
  user_data = filebase64(var.user_data)
}