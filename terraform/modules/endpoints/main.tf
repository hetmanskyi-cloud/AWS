# --- Main Configuration for VPC Endpoints --- #

# --- SSM Interface Endpoint --- #
# Provides access to AWS Systems Manager (SSM) for instances in private subnets.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.endpoints_sg.id] # Created by this module

  # Optional: Enable CloudWatch Logs for monitoring traffic
  policy = var.enable_cloudwatch_logs_for_endpoints ? data.aws_iam_policy_document.endpoint_ssm_doc[0].json : null

  tags = local.tags
}

# --- SSM Messages Interface Endpoint --- #
# Provides access to SSM Messages, required for Systems Manager Agent communication.
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.endpoints_sg.id] # Created by this module

  tags = local.tags
}

# --- EC2 Messages Interface Endpoint --- #
# Provides access to EC2 Messages for Systems Manager operations.
resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.endpoints_sg.id] # Created by this module

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
}

# --- Local Tags for Resources --- #
locals {
  tags = {
    Name        = "${var.name_prefix}-endpoint"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. This module creates Interface Endpoints for SSM, SSM Messages, and EC2 Messages (Gateway Endpoints for S3 and DynamoDB creates in `vpc module`).
# 2. Security Group for Interface Endpoints allows HTTPS access (port 443) only from private subnets.
# 3. CloudWatch Logs are optional and can be enabled for monitoring traffic.
# 4. Tags are applied to all resources for better identification and management across environments.