# --- Outputs for VPC Endpoints --- #

# --- SSM Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for AWS Systems Manager (SSM).
output "ssm_endpoint_id" {
  description = "The ID of the SSM Interface Endpoint"
  value       = try(aws_vpc_endpoint.ssm.id, null)
}

# --- SSM Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for SSM Messages, used by the Systems Manager Agent.
output "ssm_messages_endpoint_id" {
  description = "The ID of the SSM Messages Interface Endpoint"
  value       = try(aws_vpc_endpoint.ssm_messages.id, null)
}

# --- SSM Messages Interface Endpoint DNS Names --- #
output "ssm_messages_endpoint_dns_names" {
  description = "DNS names for the SSM Messages Interface Endpoint"
  value       = [for entry in aws_vpc_endpoint.ssm_messages.dns_entry : entry.dns_name]
}

# --- ASG Messages Interface Endpoint DNS Names --- #
output "asg_messages_endpoint_dns_names" {
  description = "DNS names for the ASG Messages Interface Endpoint"
  value       = [for entry in aws_vpc_endpoint.asg_messages.dns_entry : entry.dns_name]
}

# --- Endpoint States --- #
output "endpoints_state" {
  description = "State of all VPC endpoints"
  value = {
    ssm          = aws_vpc_endpoint.ssm.state
    ssm_messages = aws_vpc_endpoint.ssm_messages.state
    asg_messages = aws_vpc_endpoint.asg_messages.state
  }
}

# --- ASG Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for ASG Messages, used for Systems Manager communications.
output "asg_messages_endpoint_id" {
  description = "The ID of the ASG Messages Interface Endpoint"
  value       = try(aws_vpc_endpoint.asg_messages.id, null)
}

# --- Endpoint Security Group ID --- #
# Outputs the ID of the Security Group created for VPC Endpoints to allow controlled access.
output "endpoint_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = aws_security_group.endpoints_sg.id
}

# --- SSM Interface Endpoint DNS Names --- #
# Outputs the DNS names for the Interface Endpoint for AWS Systems Manager (SSM).
output "ssm_endpoint_dns_names" {
  description = "DNS names for the SSM Interface Endpoint"
  value       = [for entry in aws_vpc_endpoint.ssm.dns_entry : entry.dns_name]
}

# Output ARN of the CloudWatch Log Group for VPC Endpoints
output "endpoints_log_group_arn" {
  description = <<-EOT
    ARN of the CloudWatch Log Group for VPC Endpoints.
    Returns null if CloudWatch logging is not enabled.
  EOT
  value       = try(aws_cloudwatch_log_group.endpoint_logs[0].arn, null)
}

# Output name of the CloudWatch Log Group for VPC Endpoints
output "endpoints_log_group_name" {
  description = <<-EOT
    Name of the CloudWatch Log Group for VPC Endpoints.
    Returns null if CloudWatch logging is not enabled.
  EOT
  value       = try(aws_cloudwatch_log_group.endpoint_logs[0].name, null)
}

# --- Notes --- #
# 1. Outputs include the IDs of VPC Endpoints (Interface) created by this module.
# 2. The Security Group ID is provided for Interface Endpoints to manage inbound and outbound rules.
# 3. These outputs can be referenced by other modules or resources for integration.