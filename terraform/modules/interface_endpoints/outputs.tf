# --- Interface Endpoints Module Outputs --- #

# --- SSM Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for AWS Systems Manager (SSM).
output "ssm_endpoint_id" {
  description = "The ID of the SSM Interface Endpoint"
  value       = try(aws_vpc_endpoint.ssm[0].id, null)
}

# --- SSM Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for SSM Messages, used by the Systems Manager Agent.
output "ssm_messages_endpoint_id" {
  description = "The ID of the SSM Messages Interface Endpoint"
  value       = try(aws_vpc_endpoint.ssm_messages[0].id, null)
}

# --- ASG Messages Interface Endpoint ID --- #
# Outputs the ID of the Interface Endpoint for ASG Messages, used for Systems Manager communications.
output "asg_messages_endpoint_id" {
  description = "The ID of the ASG Messages Interface Endpoint"
  value       = try(aws_vpc_endpoint.asg_messages[0].id, null)
}

# --- Endpoint Security Group Output --- #
# Outputs the Security Group ID associated with the Interface VPC Endpoints.
# This Security Group controls HTTPS (TCP 443) access for SSM, SSM Messages, ASG Messages, CloudWatch Logs, and KMS endpoints.
output "endpoint_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = length(aws_security_group.endpoints_sg) > 0 ? aws_security_group.endpoints_sg[0].id : null
}

# --- CloudWatch Logs Endpoint --- #
output "cloudwatch_logs_endpoint_id" {
  description = "The ID of the CloudWatch Logs Interface Endpoint"
  value       = try(aws_vpc_endpoint.cloudwatch_logs[0].id, null)
}

# --- KMS Endpoint --- #
output "kms_endpoint_id" {
  description = "The ID of the KMS Interface Endpoint"
  value       = try(aws_vpc_endpoint.kms[0].id, null)
}

# --- Notes --- #
# 1. Outputs include the IDs of VPC Endpoints (Interface) created by this module.
# 2. The Security Group ID is provided for Interface Endpoints to manage inbound and outbound rules.
# 3. These outputs can be referenced by other modules or resources for integration.
