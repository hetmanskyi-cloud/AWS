# --- Internet Gateway Configuration --- #
# Creates an Internet Gateway (IGW) to enable internet access for resources in the public subnet(s).
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw-${var.environment}"
  })
}

# --- NAT Gateway Resources (Conditional) --- #
# The logic below creates one NAT Gateway per unique Availability Zone for High Availability (HA),
# or a single NAT Gateway if single_nat_gateway is true.
# This prevents creating costly duplicate gateways in the same AZ if multiple public subnets are defined there.
locals {
  # 1. Get a set of unique Availability Zones from the public subnets map.
  # This is the basis for HA NAT Gateway creation.
  public_subnet_azs = toset([for subnet in var.public_subnets : subnet.availability_zone])

  # 2. Create a map where each AZ keys a list of the public subnet keys in that AZ.
  # Example: { "eu-west-1a" = ["public-1a", "public-dmz-1a"], "eu-west-1b" = ["public-1b"] }
  public_subnet_keys_by_az = {
    for az in local.public_subnet_azs : az => [
      for key, subnet in var.public_subnets : key if subnet.availability_zone == az
    ]
  }

  # 3. Determine the set of AZs that will host a NAT Gateway in HA mode.
  # If HA mode is disabled, this set is empty.
  nat_gateway_azs = var.enable_nat_gateway && !var.single_nat_gateway ? local.public_subnet_azs : toset([])
}

# EIPs for NAT Gateways
# In HA mode, one EIP is created for each unique AZ.
# In Single mode, only one EIP is created.
resource "aws_eip" "nat_ha" {
  for_each = local.nat_gateway_azs
  domain   = "vpc"
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-ha-${each.key}-${var.environment}"
  })
}

resource "aws_eip" "nat_single" {
  count  = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-single-${var.environment}"
  })
}

# NAT Gateways
# In HA mode, one NAT Gateway is created per unique AZ, placed in the first public subnet of that AZ.
# In Single mode, one NAT Gateway is created and placed in the first public subnet available.
resource "aws_nat_gateway" "nat_ha" {
  for_each = local.nat_gateway_azs

  # An EIP is required for the NAT Gateway
  allocation_id = aws_eip.nat_ha[each.key].id

  # Place the NAT Gateway in the first public subnet found for that AZ.
  # It's safe to pick the first one as all public subnets in an AZ share the same public route table.
  subnet_id = aws_subnet.public[local.public_subnet_keys_by_az[each.key][0]].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway-${each.key}-${var.environment}"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_single" {
  count = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_single[0].id
  subnet_id     = values(aws_subnet.public)[0].id # Place in the first available public subnet

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway-${var.environment}"
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
    Name = "${var.name_prefix}-public-route-table${var.environment}"
  })
}

# Associate the public route table with all public subnets.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# --- Private Route Table Configuration (per-AZ for HA) --- #
# A route table is created for each private subnet to route traffic to the appropriate NAT Gateway.
#
# IMPORTANT: This configuration assumes network symmetry for HA mode.
# In High Availability mode (!single_nat_gateway), the lookup for a NAT Gateway is based on the Availability Zone
# of the *private* subnet. This implies that for every private subnet in a given AZ (e.g., 'eu-west-1a'),
# there must be at least one public subnet in the *same* AZ.
# If this condition is not met, Terraform will fail because it won't find a corresponding NAT Gateway
# (as they are only created in AZs with public subnets).
resource "aws_route_table" "private" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.vpc.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      # If single_nat_gateway is true, use the single NAT.
      # Otherwise, look up the correct HA NAT Gateway for the private subnet's specific AZ.
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat_single[0].id : aws_nat_gateway.nat_ha[each.value.availability_zone].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-route-table-${each.key}-${var.environment}"
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
  service_name    = "com.amazonaws.${var.aws_region}.s3"
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
