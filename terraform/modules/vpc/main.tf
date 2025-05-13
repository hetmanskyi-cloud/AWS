# --- VPC Configuration --- #
# Main VPC configuration with CIDR block and DNS support enabled

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# --- Public Subnet Configurations --- #
# Define three public subnets, each with public IP assignment enabled for instances.

# Public Subnet 1
# Public subnets must have public IP assignment enabled for instances that require direct internet access.
# checkov:skip=CKV_AWS_130: Public subnet requires public IPs to allow EC2 internet access for WordPress installation and updates
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_1
  map_public_ip_on_launch = true # tfsec:ignore:aws-ec2-no-public-ip-subnet
  availability_zone       = var.availability_zone_public_1

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-1"
  })
}

# Public Subnet 2
# Public subnets must have public IP assignment enabled for instances that require direct internet access.
# checkov:skip=CKV_AWS_130: Public subnet requires public IPs to allow EC2 internet access for WordPress installation and updates
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_2
  map_public_ip_on_launch = true # tfsec:ignore:aws-ec2-no-public-ip-subnet
  availability_zone       = var.availability_zone_public_2

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-2"
  })
}

# Public Subnet 3
# Public subnets must have public IP assignment enabled for instances that require direct internet access.
# tfsec:ignore:aws-ec2-no-public-ip-subnet
# checkov:skip=CKV_AWS_130: Public subnet requires public IPs to allow EC2 internet access for WordPress installation and updates
resource "aws_subnet" "public_subnet_3" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_3
  map_public_ip_on_launch = true # tfsec:ignore:aws-ec2-no-public-ip-subnet
  availability_zone       = var.availability_zone_public_3

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-3"
  })
}

# --- Private Subnet Configurations --- #
# Define three private subnets without public IP assignment.

# Private Subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr_block_1
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zone_private_1

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-1"
  })
}

# Private Subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr_block_2
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zone_private_2

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-2"
  })
}

# Private Subnet 3
resource "aws_subnet" "private_subnet_3" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr_block_3
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zone_private_3

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-3"
  })
}

# --- Default Security Group Restrictions --- #
# Restrict all inbound and outbound traffic for the default security group in the VPC.
# This ensures that no unintended traffic is allowed.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id # Associate with the created VPC

  # By default, AWS allows all traffic within the default security group.
  # This configuration removes all rules to enforce strict traffic control.
  # Remove all inbound and outbound rules to fully restrict traffic.
  ingress = []
  egress  = []

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-default-sg"
  })
}

# --- Notes --- #
# 1. The VPC is configured with both public and private subnets to support various workloads.
# 2. Public subnets allow internet access through the Internet Gateway (IGW).
# 3. Private subnets are isolated and do not have direct internet access or public IPs by default, 
#    providing a secure environment for sensitive resources (e.g., databases).
# 4. All subnets and resources are tagged with a consistent naming convention for easy management.
# 5. Ensure `map_public_ip_on_launch` is enabled only for public subnets.
# 6. Default Security Group:
#    - The default security group for the VPC is restricted to avoid unintended access.
#    - It is recommended to use custom security groups for precise control over instance access.
# 7. VPC Flow Logs:
#    - Captures all traffic types for auditing and troubleshooting.
#    - Logs are sent to CloudWatch with KMS encryption.
#    - VPC Flow Logs are configured in vpc/flow_logs.tf