# --- VPC Outputs --- #

# Output the VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

# --- Public Subnet Outputs --- #

# Output IDs for public subnets
output "public_subnet_1_id" {
  description = "ID of the first public subnet"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  description = "ID of the second public subnet"
  value       = aws_subnet.public_subnet_2.id
}

output "public_subnet_3_id" {
  description = "ID of the third public subnet"
  value       = aws_subnet.public_subnet_3.id
}

# --- Private Subnet Outputs --- #

# Output IDs for private subnets
output "private_subnet_1_id" {
  description = "ID of the first private subnet"
  value       = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  description = "ID of the second private subnet"
  value       = aws_subnet.private_subnet_2.id
}

output "private_subnet_3_id" {
  description = "ID of the third private subnet"
  value       = aws_subnet.private_subnet_3.id
}

# --- Flow Logs Outputs --- #

# Output for CloudWatch Log Group
output "vpc_flow_logs_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_log_group.name
}

# IAM Role ARN for VPC Flow Logs; used by Flow Logs to write to CloudWatch or S3
output "vpc_flow_logs_role_arn" {
  description = "IAM Role ARN for VPC Flow Logs"
  value       = aws_iam_role.vpc_flow_logs_role.arn
}

# --- Additional Outputs for CIDR Blocks --- #

# Output the CIDR block for the first public subnet
output "public_subnet_cidr_block_1" {
  description = "CIDR block for the first public subnet"
  value       = aws_subnet.public_subnet_1.cidr_block
}

# Output the CIDR block for the second public subnet
output "public_subnet_cidr_block_2" {
  description = "CIDR block for the second public subnet"
  value       = aws_subnet.public_subnet_2.cidr_block
}

# Output the CIDR block for the third public subnet
output "public_subnet_cidr_block_3" {
  description = "CIDR block for the third public subnet"
  value       = aws_subnet.public_subnet_3.cidr_block
}

# Output the CIDR block for the first private subnet
output "private_subnet_cidr_block_1" {
  description = "CIDR block for the first private subnet"
  value       = aws_subnet.private_subnet_1.cidr_block
}

# Output the CIDR block for the second private subnet
output "private_subnet_cidr_block_2" {
  description = "CIDR block for the second private subnet"
  value       = aws_subnet.private_subnet_2.cidr_block
}

# Output the CIDR block for the third private subnet
output "private_subnet_cidr_block_3" {
  description = "CIDR block for the third private subnet"
  value       = aws_subnet.private_subnet_3.cidr_block
}

# --- Private Route Table Output ---
# Output for the private route table ID, used for routing traffic within private subnets.
# This route table does not connect to the Internet Gateway and routes traffic only within VPC resources.

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private_route_table.id
}

# --- Public Route Table Output ---
# Output for the public route table ID, used for routing Internet traffic in public subnets through the Internet Gateway.

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_route_table.id
}
