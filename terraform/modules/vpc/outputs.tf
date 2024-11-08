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

