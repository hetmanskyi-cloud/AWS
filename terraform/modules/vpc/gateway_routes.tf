# --- Internet Gateway Configuration --- #
# Creates an Internet Gateway (IGW) to enable internet access for resources in the public subnet(s).

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-igw"
    Environment = var.environment
  }
}

# --- Public Route Table Configuration --- #
# This route table provides internet access to resources in public subnets via the Internet Gateway (IGW).

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  # Route all outbound internet-bound traffic (0.0.0.0/0) through the Internet Gateway.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.name_prefix}-public-route-table"
    Environment = var.environment
  }

  # Ensures this route table is created after the Internet Gateway
  depends_on = [aws_internet_gateway.igw]
}

# --- Public Subnet Route Table Association --- #
# Associate the public route table with each public subnet to enable internet access.

# Association for Public Subnet 1
resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Association for Public Subnet 2
resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Association for Public Subnet 3
resource "aws_route_table_association" "public_route_table_association_3" {
  subnet_id      = aws_subnet.public_subnet_3.id
  route_table_id = aws_route_table.public_route_table.id
}
