# --- Internet Gateway Configuration --- #

# Create an Internet Gateway to provide internet access to resources in the public subnets.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-igw" # Name tag for easy identification
    Environment = var.environment          # Tag for environment (e.g., dev, staging, prod)
  }
}

# --- Public Route Table Configuration --- #

# Create a route table for public subnets to enable internet access via the Internet Gateway.
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id # Link the route table to the VPC

  # Add a route for all traffic (0.0.0.0/0) to go through the Internet Gateway for internet access.
  route {
    cidr_block = "0.0.0.0/0"                 # Default route for all internet-bound traffic
    gateway_id = aws_internet_gateway.igw.id # Use the created Internet Gateway as the route target
  }

  tags = {
    Name        = "${var.name_prefix}-public-route-table" # Name tag for the public route table
    Environment = var.environment                         # Environment tag for organization
  }
}

# --- Public Subnet Route Table Associations --- #

# Associate the public route table with each public subnet to ensure internet access.

# Association for Public Subnet 1
resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id         # ID of the first public subnet
  route_table_id = aws_route_table.public_route_table.id # Public route table ID
}

# Association for Public Subnet 2
resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id         # ID of the second public subnet
  route_table_id = aws_route_table.public_route_table.id # Public route table ID
}

# Association for Public Subnet 3
resource "aws_route_table_association" "public_route_table_association_3" {
  subnet_id      = aws_subnet.public_subnet_3.id         # ID of the third public subnet
  route_table_id = aws_route_table.public_route_table.id # Public route table ID
}

# --- Private Route Tables for Private Subnets --- #

# Define private route tables for each private subnet.
# These route tables do not include a route to the internet, ensuring the subnets remain private.

# Private Route Table for Subnet 1
# Private route tables do not include internet routes; subnets remain isolated without NAT
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-private-route-table-1" # Name for easy identification
    Environment = var.environment                            # Environment tag
  }
}

# Private Route Table for Subnet 2
# Private route tables do not include internet routes; subnets remain isolated without NAT
resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-private-route-table-2" # Name for easy identification
    Environment = var.environment                            # Environment tag
  }
}

# Private Route Table for Subnet 3
# Private route tables do not include internet routes; subnets remain isolated without NAT
resource "aws_route_table" "private_route_table_3" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-private-route-table-3" # Name for easy identification
    Environment = var.environment                            # Environment tag
  }
}

# --- Private Subnet Route Table Associations --- #

# Associate each private route table with its respective private subnet.

# Association for Private Subnet 1
resource "aws_route_table_association" "private_route_table_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id           # ID of the first private subnet
  route_table_id = aws_route_table.private_route_table_1.id # Private route table ID for subnet 1
}

# Association for Private Subnet 2
resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id           # ID of the second private subnet
  route_table_id = aws_route_table.private_route_table_2.id # Private route table ID for subnet 2
}

# Association for Private Subnet 3
resource "aws_route_table_association" "private_route_table_association_3" {
  subnet_id      = aws_subnet.private_subnet_3.id           # ID of the third private subnet
  route_table_id = aws_route_table.private_route_table_3.id # Private route table ID for subnet 3
}
