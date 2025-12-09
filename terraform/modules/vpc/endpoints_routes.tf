# --- Internet Gateway Configuration --- #
# Creates an Internet Gateway (IGW) to enable internet access for resources in the public subnet(s).
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw-${var.environment}"
  })
}

# --- NAT Gateway Resources (Conditional) --- #
locals {
  # Create a map of AZ -> NAT Gateway ID for HA routing.
  # This is only used when enable_nat_gateway is true and single_nat_gateway is false.
  az_to_nat_gateway_id = var.enable_nat_gateway && !var.single_nat_gateway ? {
    for i, pub_subnet_key in keys(var.public_subnets) :
    var.public_subnets[pub_subnet_key].availability_zone => aws_nat_gateway.nat[i].id
  } : {}
}

# EIP for NAT Gateway(s)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name_prefix}-nat-eip-${var.environment}" : "${var.name_prefix}-nat-eip-${keys(var.public_subnets)[count.index]}-${var.environment}"
  })
}

# NAT Gateway(s)
resource "aws_nat_gateway" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0

  allocation_id = aws_eip.nat[count.index].id
  # Place NAT Gateway in a public subnet.
  # For HA, one is placed in each public subnet's AZ. For single, it's placed in the first one.
  subnet_id = aws_subnet.public[keys(var.public_subnets)[count.index]].id

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name_prefix}-nat-gateway-${var.environment}" : "${var.name_prefix}-nat-gateway-${keys(var.public_subnets)[count.index]}-${var.environment}"
  })

  depends_on = [aws_internet_gateway.igw]
}


# --- Public Route Table Configuration --- #
# This route table provides internet access to resources in public subnets via the Internet Gateway (IGW).
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt-${var.environment}"
  })
}

# Associate the public route table with all public subnets.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# --- Private Route Table Configuration (per-AZ for HA) --- #
# A route table is created for each private subnet to route traffic to the NAT Gateway in the same AZ.
resource "aws_route_table" "private" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.vpc.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : local.az_to_nat_gateway_id[each.value.availability_zone]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${each.key}-${var.environment}"
  })
}

# Associate each private subnet with its corresponding private route table.
resource "aws_route_table_association" "private" {
  for_each = var.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}


# --- Gateway Endpoints --- #
# S3 and DynamoDB Gateway Endpoints for private access from all subnets.
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.vpc.id
  route_table_ids = toset(concat([aws_route_table.public.id], [for rt in values(aws_route_table.private) : rt.id]))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-endpoint-${var.environment}"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = toset(concat([aws_route_table.public.id], [for rt in values(aws_route_table.private) : rt.id]))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dynamodb-endpoint-${var.environment}"
  })
}

# --- Notes --- #
# 1. NAT Gateway: Conditionally created to provide outbound internet access for private subnets.
#    - single_nat_gateway=true: A single NAT gateway is created in one AZ. Cost-effective but not highly available.
#    - single_nat_gateway=false: A NAT gateway is created in each AZ where a public subnet exists, providing high availability.
# 2. Private Route Tables: Each private subnet gets its own route table to enable AZ-specific routing to the corresponding NAT Gateway.
# 3. Gateway Endpoints: S3 and DynamoDB endpoints are associated with both the public route table and all private route tables to ensure private, efficient access from all subnets.
