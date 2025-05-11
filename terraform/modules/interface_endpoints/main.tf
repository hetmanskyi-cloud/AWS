# --- VPC Interface Endpoints (Future Use) --- #
# This module is currently disabled but remains as a future-proofing measure.
# It allows private communication with AWS services (SSM, CloudWatch, KMS, etc.)
# if EC2 instances are later moved to private subnets without internet access.
# 
# For now, instances are in public subnets with direct internet access, so 
# enabling this module is unnecessary. To enable, set `enable_interface_endpoints = true`.

resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_interface_endpoints ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"

  # Deploy endpoint ENIs across all private subnets for AZ redundancy.
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ssm-endpoint"
  })
}

# --- SSM Messages Interface Endpoint --- #
resource "aws_vpc_endpoint" "ssm_messages" {
  count = var.enable_interface_endpoints ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ssm-messages-endpoint"
  })
}

# --- ASG Messages Interface Endpoint (EC2 Messages for Auto Scaling) --- #
resource "aws_vpc_endpoint" "asg_messages" {
  count = var.enable_interface_endpoints ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-asg-messages-endpoint"
  })
}

# --- CloudWatch Logs Interface Endpoint --- #
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  count = var.enable_interface_endpoints ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudwatch-logs-endpoint"
  })
}

# --- KMS Interface Endpoint --- #
resource "aws_vpc_endpoint" "kms" {
  count = var.enable_interface_endpoints ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-kms-endpoint"
  })
}

# --- Notes --- #
# 1. This module creates Interface Endpoints for multiple AWS services such as SSM, SSM Messages,
#    EC2 Messages, CloudWatch Logs, and KMS.
#    Gateway Endpoints for S3 and DynamoDB are managed separately in the VPC module.
#
# 2. Each Interface Endpoint is configured to use all private subnets. This ensures an ENI is created
#    in each Availability Zone, allowing instances in any AZ to communicate with AWS services
#    privately (without NAT or public IPs).
#
# 3. Security:
#    - The Security Group for these endpoints permits inbound HTTPS (TCP port 443) from within the VPC.
#    - If you need stricter rules, you can limit the source to specific Security Groups or CIDR blocks.
#    - Optionally, you can enable CloudWatch Logs to monitor endpoint traffic.
#
# 4. Best Practices:
#    - Apply consistent tagging to all resources for better organization.
#    - Using a single resource per service with a list of all private subnets avoids issues like
#      DuplicateSubnetsInSameZone and simplifies endpoint management.
#    - Enable private DNS so instances can use the standard service URLs (e.g., ssm.<region>.amazonaws.com).
#    - Ensure your EC2 instances have an IAM role (e.g., AmazonSSMManagedInstanceCore) so that SSM Agent
#      can register and communicate properly.