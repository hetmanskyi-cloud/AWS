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

# --- Lambda Endpoint --- #
output "lambda_endpoint_id" {
  description = "The ID of the Lambda Interface Endpoint"
  value       = try(aws_vpc_endpoint.lambda.id, null)
}

# --- CloudWatch Logs Endpoint --- #
output "cloudwatch_logs_endpoint_id" {
  description = "The ID of the CloudWatch Logs Interface Endpoint"
  value       = try(aws_vpc_endpoint.cloudwatch_logs.id, null)
}

# --- SQS Endpoint --- #
output "sqs_endpoint_id" {
  description = "The ID of the SQS Interface Endpoint"
  value       = try(aws_vpc_endpoint.sqs.id, null)
}

# --- KMS Endpoint --- #
output "kms_endpoint_id" {
  description = "The ID of the KMS Interface Endpoint"
  value       = try(aws_vpc_endpoint.kms.id, null)
}

# --- Notes --- #
# 1. Outputs include the IDs and DNS names of VPC Endpoints (Interface) created by this module.
# 2. The Security Group ID is provided for Interface Endpoints to manage inbound and outbound rules.
# 3. These outputs can be referenced by other modules or resources for integration.
# 4. DNS names are essential for services to communicate with the endpoints within the VPC.