# --- VPC Configuration --- #

# Define the VPC configuration with CIDR block and DNS support enabled

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
  }
}

# --- Public Subnet 1 Configuration --- #

# Define the first public subnet with public IP assignment enabled
# Automatically assign a public IP to instances in this subnet for internet access
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id                 # Link the subnet to the created VPC
  cidr_block              = var.public_subnet_cidr_block_1 # CIDR block for the first public subnet
  map_public_ip_on_launch = true                           # Automatically assign a public IP to instances in this subnet
  availability_zone       = var.availability_zone_public_1 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-public-subnet-1" # Dynamic name for the public subnet
    Environment = var.environment                      # Environment tag for resource organization
  }
}

# --- Public Subnet 2 Configuration --- #

# Define the second public subnet with public IP assignment enabled
# Automatically assign a public IP to instances in this subnet for internet access
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id                 # Link the subnet to the created VPC
  cidr_block              = var.public_subnet_cidr_block_2 # CIDR block for the first public subnet
  map_public_ip_on_launch = true                           # Automatically assign a public IP to instances in this subnet
  availability_zone       = var.availability_zone_public_2 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-public-subnet-2" # Dynamic name for the public subnet
    Environment = var.environment                      # Environment tag for resource organization
  }
}

# --- Public Subnet 3 Configuration --- #

# Define the third public subnet with public IP assignment enabled
# Automatically assign a public IP to instances in this subnet for internet access
resource "aws_subnet" "public_subnet_3" {
  vpc_id                  = aws_vpc.vpc.id                 # Link the subnet to the created VPC
  cidr_block              = var.public_subnet_cidr_block_3 # CIDR block for the first public subnet
  map_public_ip_on_launch = true                           # Automatically assign a public IP to instances in this subnet
  availability_zone       = var.availability_zone_public_3 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-public-subnet-3" # Dynamic name for the public subnet
    Environment = var.environment                      # Environment tag for resource organization
  }
}

# --- Private Subnet 1 Configuration --- #

# Define the first private subnet, without public IP assignment
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc.id                  # Link the private subnet to the VPC
  cidr_block        = var.private_subnet_cidr_block_1 # CIDR block for the private subnet 1
  availability_zone = var.availability_zone_private_1 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-private-subnet-1" # Dynamic name for private subnet 1
    Environment = var.environment                       # Environment tag for resource organization
  }
}

# --- Private Subnet 2 Configuration --- #

# Define the second private subnet, without public IP assignment
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc.id                  # Link the private subnet to the VPC
  cidr_block        = var.private_subnet_cidr_block_2 # CIDR block for the private subnet 2
  availability_zone = var.availability_zone_private_2 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-private-subnet-2" # Dynamic name for private subnet 2
    Environment = var.environment                       # Environment tag for resource organization
  }
}

# --- Private Subnet 3 Configuration --- #

# Define the third private subnet, without public IP assignment
resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.vpc.id                  # Link the private subnet to the VPC
  cidr_block        = var.private_subnet_cidr_block_3 # CIDR block for the private subnet 2
  availability_zone = var.availability_zone_private_3 # Specify the Availability Zone for this subnet

  tags = {
    Name        = "${var.name_prefix}-private-subnet-3" # Dynamic name for private subnet 2
    Environment = var.environment                       # Environment tag for resource organization
  }
}