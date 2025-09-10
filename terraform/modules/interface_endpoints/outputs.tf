# --- Interface Endpoints Module Outputs --- #

# --- VPC Endpoint IDs --- #
# A map of the created VPC endpoint IDs, keyed by the service name (e.g., "ssm", "kms").
output "endpoint_ids" {
  description = "A map of the VPC endpoint IDs, keyed by service name."
  value       = { for service, endpoint in aws_vpc_endpoint.main : service => endpoint.id }
}

# --- Endpoint Security Group Output --- #
# Outputs the Security Group ID associated with the Interface VPC Endpoints.
output "endpoint_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = length(aws_security_group.endpoints_sg) > 0 ? aws_security_group.endpoints_sg[0].id : null
}

# --- Notes --- #
# 1. The `endpoint_ids` output provides a convenient way to reference specific endpoints,
#    for example: `module.interface_endpoints.endpoint_ids["ssm"]`.
# 2. The Security Group ID is provided for managing network rules if needed.
