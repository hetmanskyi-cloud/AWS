# --- Main Configuration for VPC Endpoints --- #

# --- SSM Interface Endpoint --- #
# Provides access to AWS Systems Manager (SSM) for instances in private subnets.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id] # Created by this module
  private_dns_enabled = true

  # Optional: Enable CloudWatch Logs for monitoring traffic
  policy = var.enable_cloudwatch_logs_for_endpoints ? data.aws_iam_policy_document.endpoint_ssm_doc[0].json : null

  tags = local.tags
}

# --- SSM Messages Interface Endpoint --- #
# Provides access to SSM Messages, required for Systems Manager Agent communication.
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id] # Created by this module
  private_dns_enabled = true

  # Note: Combining public and private subnets is useful if access to VPC Endpoints is required from both.
  # For most cases, private subnets are sufficient for SSM and similar services. Review your requirements carefully.

  tags = local.tags
}

# --- ASG Messages Interface Endpoint --- #
# Provides access to ASG Messages for Systems Manager operations.
resource "aws_vpc_endpoint" "asg_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id] # Created by this module
  private_dns_enabled = true

  tags = local.tags
}

# --- IAM Policy Document for SSM Endpoint --- #
# Defines the policy for allowing CloudWatch Logs actions if monitoring is enabled.
data "aws_iam_policy_document" "endpoint_ssm_doc" {
  count = var.enable_cloudwatch_logs_for_endpoints ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc-endpoints/${var.name_prefix}:*"
    ]
  }
  # Note: Wide permissions are used in testing environments for simplicity.
  # In production, replace this policy with more granular permissions targeting specific log streams.
}

# --- Local Tags for Resources --- #
locals {
  tags = {
    Name        = "${var.name_prefix}-endpoint"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. This module creates Interface Endpoints for SSM-related services.
#    Gateway Endpoints (S3 and DynamoDB) are managed by the VPC module
#    to maintain clear separation of concerns and avoid duplication.
# 2. Security Group for Interface Endpoints allows HTTPS access (port 443) only from private subnets.
# 3. CloudWatch Logs are optional and can be enabled for monitoring traffic.
# 4. Tags are applied to all resources for better identification and management across environments.