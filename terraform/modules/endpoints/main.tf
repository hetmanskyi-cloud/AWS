# --- Main Configuration for VPC Endpoints --- #

# --- SSM Interface Endpoint --- #
# Provides access to AWS Systems Manager (SSM) for instances in private subnets.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id] # Created by this module; no need to pass externally as no other SGs exist.

  # Optional: Enable CloudWatch Logs for monitoring traffic (stage and prod only)
  policy = var.enable_cloudwatch_logs_for_endpoints ? jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = ["*"]
      Resource = "*"
    }]
  }) : null

  tags = local.tags
}

# --- SSM Messages Interface Endpoint --- #
# Provides access to SSM Messages, required for Systems Manager Agent communication.
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  tags = local.tags
}

# --- EC2 Messages Interface Endpoint --- #
# Provides access to EC2 Messages for Systems Manager operations.
resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  tags = local.tags
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
# 3. CloudWatch Logs are optional and can be enabled for monitoring traffic in stage and prod environments.
# 4. Tags are applied to all resources for better identification and management across environments.