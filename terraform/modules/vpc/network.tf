locals {
  # This local map is created only when using the High Availability NAT Gateway strategy.
  # It maps an Availability Zone (e.g., "eu-west-1a") to the ID of the NAT Gateway in that AZ.
  # This provides a reliable way to route traffic from a private subnet in a given AZ
  # to the corresponding NAT Gateway.
  az_to_ha_nat_id = {
    # We iterate over the 'nat_ha' resources. The key 'k' corresponds to the key of the public subnet
    # where the NAT gateway resides (e.g., 'public-subnet-a').
    # We use this key to look up the availability zone of that public subnet.
    for k, nat in aws_nat_gateway.nat_ha : aws_subnet.public[k].availability_zone => nat.id
  }
}

# --- Internet Gateway (IGW) --- #
# An Internet Gateway is a horizontally scaled, redundant, and highly available VPC component
# that allows communication between instances in your VPC and the internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw-${var.environment}"
  })
}

# --- Elastic IPs for NAT Gateways --- #
# EIPs are created to provide NAT Gateways with a static public IP address.
# The number and structure of EIPs depend on the NAT Gateway strategy.
resource "aws_eip" "nat_single" {
  # Create one EIP if a single NAT Gateway is enabled for the whole VPC.
  count  = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip-nat-${var.environment}"
  })
}

resource "aws_eip" "nat_ha" {
  # For High Availability, create one EIP for each public subnet that will host a NAT Gateway.
  # Using for_each on a filtered map ensures EIPs are created only when needed.
  for_each = var.enable_nat_gateway && !var.single_nat_gateway ? {
    for k, v in var.public_subnets : k => v
  } : {}
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip-nat-${each.value.availability_zone}-${var.environment}"
  })
}

# --- NAT Gateways --- #
# NAT Gateways enable instances in a private subnet to connect to the internet or other AWS services,
# but prevent the internet from initiating a connection with those instances.
resource "aws_nat_gateway" "nat_single" {
  # Create a single NAT Gateway for the entire VPC if the single gateway strategy is chosen.
  count         = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat_single[0].id
  # Place it in the first public subnet (sorted by ID for deterministic placement).
  subnet_id = sort([for s in aws_subnet.public : s.id])[0]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway-${var.environment}"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_ha" {
  # For High Availability, create one NAT Gateway for each public subnet.
  # Using for_each makes the configuration robust and easy to read.
  for_each      = var.enable_nat_gateway && !var.single_nat_gateway ? aws_subnet.public : {}
  allocation_id = aws_eip.nat_ha[each.key].id
  subnet_id     = each.value.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway-${each.value.availability_zone}-${var.environment}"
  })

  depends_on = [aws_internet_gateway.igw]
}

# --- Public Route Table --- #
# This route table is for public subnets and includes a route to the Internet Gateway,
# allowing instances in these subnets to communicate directly with the internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rtb-${var.environment}"
  })
}

# --- Private Route Tables (One per AZ) --- #
# Creates one route table for each Availability Zone that contains private subnets. This is
# a best practice for managing routes efficiently, as all private subnets in an AZ share the same routing rules.
resource "aws_route_table" "private" {
  # Create a route table for each AZ where a private subnet exists.
  for_each = toset([for s in var.private_subnets : s.availability_zone])
  vpc_id   = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rtb-${each.key}-${var.environment}"
  })
}

# --- Default Route for Private Subnets (to NAT Gateway) --- #
# This resource adds a route to each private route table that directs internet-bound traffic (0.0.0.0/0)
# to the appropriate NAT Gateway. This is only created if 'enable_nat_gateway' is true.
resource "aws_route" "private_internet_access" {
  # Create a route for each private route table if NAT is enabled.
  for_each = var.enable_nat_gateway ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  # Determine the NAT Gateway:
  # - If 'single_nat_gateway' is true, use the single NAT gateway.
  # - If false (HA mode), find the NAT gateway in the same AZ as the route table using our local map.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat_single[0].id : local.az_to_ha_nat_id[each.key]
}

# --- Route Table Associations --- #

# Associate public subnets with the public route table. Each public subnet gets the same
# set of rules, providing a path to the Internet Gateway.
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with their respective private route tables. All private subnets
# in the same AZ will share a route table, simplifying route management.
resource "aws_route_table_association" "private" {
  for_each  = aws_subnet.private
  subnet_id = each.value.id
  # The key for the correct private route table is the subnet's availability zone.
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}

# --- Gateway Endpoints --- #
# S3 and DynamoDB Gateway Endpoints for private access from all subnets.
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  # Associate the endpoint with all public and private route tables.
  route_table_ids = toset(concat([aws_route_table.public.id], values(aws_route_table.private)[*].id))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-endpoint-${var.environment}"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  # Associate the endpoint with all public and private route tables.
  route_table_ids = toset(concat([aws_route_table.public.id], values(aws_route_table.private)[*].id))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dynamodb-endpoint-${var.environment}"
  })
}

# --- VPC Networking Notes --- #
#
# This file defines the core networking infrastructure for the VPC.
#
# --- Components --- #
# 1.  Internet Gateway (IGW): Provides a target in your VPC route tables for internet-routable
#     traffic, and performs network address translation (NAT) for instances that have been
#     assigned public IPv4 addresses.
#
# 2.  Elastic IPs (EIPs): Static public IP addresses allocated for the NAT Gateways, ensuring
#     a stable IP for outbound traffic.
#
# 3.  NAT Gateways: Enable instances in private subnets to connect to the internet or other
#     AWS services, but prevent the internet from initiating a connection with those instances.
#     - Single Gateway Mode (`var.single_nat_gateway = true`): A single NAT Gateway is deployed
#       into one public subnet and shared by all private subnets. Cost-effective for dev/test.
#     - HA Gateway Mode (`var.single_nat_gateway = false`): A NAT Gateway is deployed in each
#       Availability Zone with a public subnet. Private subnets use the NAT in their own AZ,
#       providing high availability.
#
# 4.  Route Tables & Associations:
#     - Public Route Table: One table for all public subnets, with a default route (0.0.0.0/0)
#       to the Internet Gateway.
#     - Private Route Tables: One table per Availability Zone. The default route points to the
#       appropriate NAT Gateway.
#
# 5.  Gateway Endpoints: Provides reliable and private connectivity to S3 and DynamoDB without
#     requiring an IGW or NAT Gateway. Routes are automatically added to all route tables in
#     the VPC to use these endpoints.
#
# --- Notes --- #
# - The logic for handling single vs. HA NAT Gateways is managed with conditional resources
#   (`count` and `for_each`) based on `var.single_nat_gateway` and `var.enable_nat_gateway`.
# - The `local.az_to_ha_nat_id` map is a key piece for the HA strategy, linking each AZ to its
#   dedicated NAT Gateway ID.
# - Endpoint associations are managed in bulk using `concat` and `values` to attach them to
#   both public and private route tables simultaneously.
