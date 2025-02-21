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

# --- Private Route Table Configuration --- #
# This route table provides access to S3 and DynamoDB via Gateway Endpoints for resources in private subnets.

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name_prefix}-private-route-table"
    Environment = var.environment
  }
}

# --- Private Subnet Route Table Association --- #
# Associate the private route table with each private subnet.

# Association for Private Subnet 1
resource "aws_route_table_association" "private_route_table_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Association for Private Subnet 2
resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Association for Private Subnet 3
resource "aws_route_table_association" "private_route_table_association_3" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.private_route_table.id
}

# --- Gateway Endpoints --- #

# Gateway Endpoints for S3 and DynamoDB allow private access without requiring a NAT Gateway.
# Gateway Endpoint routes are added to both private and public route tables
# to allow ASG instances in public subnets to access S3 and DynamoDB
# via AWS private network, even when public IPs are disabled.

# --- S3 Gateway Endpoint --- #
# Provides access to Amazon S3 through a Gateway Endpoint, allowing private access without internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private_route_table.id,
    aws_route_table.public_route_table.id
  ]

  tags = {
    Name        = "${var.name_prefix}-s3-endpoint"
    Environment = var.environment
  }
}

# --- DynamoDB Endpoint --- #
# Provides access to Amazon DynamoDB through a Gateway Endpoint, allowing private access without internet.
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private_route_table.id,
    aws_route_table.public_route_table.id
  ]

  tags = {
    Name        = "${var.name_prefix}-dynamodb-endpoint"
    Environment = var.environment
  }
}

# --- Data Sources for AWS Managed Prefix Lists ---
# These prefix lists are used for Gateway Endpoints (S3 and DynamoDB)
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.aws_region}.dynamodb"
}

# --- Notes --- #
# 1. **Public route table**:
#   - Routes general outbound traffic from public subnets to the internet through the Internet Gateway (IGW).
#   - Also includes Gateway Endpoints for S3 and DynamoDB to allow instances without public IP
#     to access these services privately.

# 2. **Private route table**:
#   - Routes traffic to S3 and DynamoDB through Gateway Endpoints for private subnets.
#   - Does not allow general internet-bound traffic, ensuring private connectivity.

# 3. **Endpoint routes**:
#   - S3 and DynamoDB traffic are explicitly routed through their respective Gateway Endpoints
#     in both public and private route tables.
#   - This ensures that instances in a public subnet without a public IP can still
#     communicate with S3 and DynamoDB over private AWS networking (no NAT required).

# 4. **Subnet associations**:
#   - The public route table is associated with public subnets for internet access and AWS Gateway Endpoints.
#   - The private route table is associated with private subnets for restricted access and Gateway Endpoints.

# 5. **Best practices**:
#   - Ensure all route table associations match the intended subnet types to avoid connectivity issues.
#   - Regularly review route table configurations to maintain alignment with security and architectural requirements.
#   - Validate that public subnets without public IPs have a route to S3/DynamoDB if needed
#     (via the Gateway Endpoints).