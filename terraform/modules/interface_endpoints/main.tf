# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# This module creates Interface Endpoints for a list of specified AWS services.
# It is disabled by default and can be enabled by setting `enable_interface_endpoints = true`.

resource "aws_vpc_endpoint" "main" {
  for_each = var.enable_interface_endpoints ? toset(var.endpoint_services) : toset([])

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Interface"

  subnet_ids          = toset(var.private_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-endpoint-${var.environment}"
  })
}

# --- Notes --- #
# 1. This module uses a `for_each` loop to dynamically create endpoints for each service
#    listed in the `var.endpoint_services` variable. This makes the module flexible and reusable.
#
# 2. Gateway Endpoints for S3 and DynamoDB are managed separately, typically in the VPC module,
#    as they have a different architecture (they are not ENIs).
#
# 3. Each Interface Endpoint is configured to use all private subnets. This ensures an ENI is created
#    in each Availability Zone, allowing instances in any AZ to communicate with AWS services
#    privately (without NAT or public IPs).
#
# 4. Security:
#    - The Security Group for these endpoints permits inbound HTTPS (TCP port 443) from within the VPC.
#    - `private_dns_enabled = true` allows instances to use standard service URLs (e.g., ssm.region.amazonaws.com).
