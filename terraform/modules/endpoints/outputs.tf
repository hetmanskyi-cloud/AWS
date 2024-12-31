# --- Outputs for VPC Endpoints --- #

# --- SSM Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for AWS Systems Manager (SSM).
output "ssm_endpoint_id" {
  description = "The ID of the SSM Interface Endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

# --- SSM Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for SSM Messages, used by the Systems Manager Agent.
output "ssm_messages_endpoint_id" {
  description = "The ID of the SSM Messages Interface Endpoint"
  value       = aws_vpc_endpoint.ssm_messages.id
}

# --- EC2 Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for EC2 Messages, used for Systems Manager communications.
output "ec2_messages_endpoint_id" {
  description = "The ID of the EC2 Messages Interface Endpoint"
  value       = aws_vpc_endpoint.ec2_messages.id
}

# --- Endpoint Security Group ID --- #
# Outputs the ID of the Security Group created for VPC Endpoints to allow controlled access.
output "endpoint_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = aws_security_group.endpoints_sg.id
}

# --- Notes --- #
# 1. Outputs include the IDs of all VPC Endpoints (Gateway and Interface) created by this module.
# 2. The Security Group ID is provided for Interface Endpoints to manage inbound and outbound rules.
# 3. These outputs can be referenced by other modules or resources for integration.