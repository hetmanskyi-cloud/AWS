# --- VPC Configuration --- #
# Main VPC configuration with CIDR block and DNS support enabled

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
  }
}

# --- Public Subnet Configurations --- #
# Define three public subnets, each with public IP assignment enabled for instances.

# Public Subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_1
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_public_1

  tags = {
    Name        = "${var.name_prefix}-public-subnet-1"
    Environment = var.environment
  }
}

# Public Subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_2
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_public_2

  tags = {
    Name        = "${var.name_prefix}-public-subnet-2"
    Environment = var.environment
  }
}

# Public Subnet 3
resource "aws_subnet" "public_subnet_3" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_block_3
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_public_3

  tags = {
    Name        = "${var.name_prefix}-public-subnet-3"
    Environment = var.environment
  }
}

# --- Private Subnet Configurations --- #
# Define three private subnets without public IP assignment.

# Private Subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr_block_1
  availability_zone = var.availability_zone_private_1

  tags = {
    Name        = "${var.name_prefix}-private-subnet-1"
    Environment = var.environment
  }
}

# Private Subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr_block_2
  availability_zone = var.availability_zone_private_2

  tags = {
    Name        = "${var.name_prefix}-private-subnet-2"
    Environment = var.environment
  }
}

# Private Subnet 3
resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr_block_3
  availability_zone = var.availability_zone_private_3

  tags = {
    Name        = "${var.name_prefix}-private-subnet-3"
    Environment = var.environment
  }
}
