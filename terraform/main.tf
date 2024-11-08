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
