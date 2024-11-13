# --- Outputs for VPC Endpoints ---

# S3 Gateway Endpoint ID
output "s3_endpoint_id" {
  description = "The ID of the S3 Gateway Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

# SSM Interface Endpoint ID
output "ssm_endpoint_id" {
  description = "The ID of the SSM Interface Endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

# SSM Messages Interface Endpoint ID
output "ssm_messages_endpoint_id" {
  description = "The ID of the SSM Messages Interface Endpoint"
  value       = aws_vpc_endpoint.ssm_messages.id
}

# EC2 Messages Interface Endpoint ID
output "ec2_messages_endpoint_id" {
  description = "The ID of the EC2 Messages Interface Endpoint"
  value       = aws_vpc_endpoint.ec2_messages.id
}

# --- Endpoint Security Group Output ---

# Output for the Security Group ID created for VPC Endpoints to control access within the private network.
output "endpoint_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = aws_security_group.endpoints_sg.id
}
