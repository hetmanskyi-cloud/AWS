# --- VPC Module Outputs --- #

# Output the VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

# VPC ARN Output
output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.vpc.arn
}

# VPC CIDR Block Output
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

# --- Subnet Outputs --- #

# Output list of all public subnet IDs
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = values(aws_subnet.public)[*].id
}

# Output list of all private subnet IDs
output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = values(aws_subnet.private)[*].id
}

# Output a comprehensive map of public subnets
output "public_subnets_map" {
  description = "A map of public subnets with their details (id, cidr_block, availability_zone)."
  value = { for k, v in aws_subnet.public : k => {
    id                = v.id
    cidr_block        = v.cidr_block
    availability_zone = v.availability_zone
  } }
}

# Output a comprehensive map of private subnets
output "private_subnets_map" {
  description = "A map of private subnets with their details (id, cidr_block, availability_zone)."
  value = { for k, v in aws_subnet.private : k => {
    id                = v.id
    cidr_block        = v.cidr_block
    availability_zone = v.availability_zone
  } }
}

# --- NAT Gateway IPs --- #
output "nat_gateway_public_ips" {
  description = "List of public Elastic IP addresses assigned to the NAT Gateways."
  value       = var.enable_nat_gateway ? (var.single_nat_gateway ? aws_eip.nat_single[*].public_ip : values(aws_eip.nat_ha)[*].public_ip) : []
}

# --- Routing and Endpoint Outputs --- #

# Output for the public route table ID
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# Output for the private route table IDs
output "private_route_table_ids" {
  description = "A map of private route table IDs, keyed by the private subnet key."
  value       = { for k, v in aws_route_table.private : k => v.id }
}

# Output the ID of the S3 Gateway Endpoint
output "s3_endpoint_id" {
  description = "The ID of the S3 Gateway Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

# Output the ID of the DynamoDB Endpoint
output "dynamodb_endpoint_id" {
  description = "The ID of the DynamoDB VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

# --- Security and Logging Outputs --- #

# Output the ID of the Default Security Group
output "default_security_group_id" {
  description = "The ID of the default security group for the VPC"
  value       = aws_default_security_group.default.id
}

# Output for CloudWatch Log Group
output "vpc_flow_logs_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_log_group.name
}

# --- Notes --- #
# 1. Outputs are organized to provide all necessary IDs and CIDR blocks for subnets, route tables, and endpoints.
# 2. These outputs can be used by other modules to dynamically reference VPC resources.
# 3. Regularly validate outputs to ensure they match the desired infrastructure configuration.
