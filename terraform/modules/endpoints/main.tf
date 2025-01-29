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

  tags = {
    Name        = "${var.name_prefix}-ssm-endpoint"
    Environment = var.environment
  }
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

  tags = {
    Name        = "${var.name_prefix}-ssm-messages-endpoint"
    Environment = var.environment
  }
}

# --- ASG Messages Interface Endpoint --- #
# Provides access to EC2 Messages service for Auto Scaling Group instances and Systems Manager operations.
resource "aws_vpc_endpoint" "asg_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id] # Created by this module
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-asg-messages-endpoint"
    Environment = var.environment
  }
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
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc-endpoints/${var.name_prefix}-${var.environment}:*"
    ]
  }
  # Note: Wide permissions are used in testing environments for simplicity.
  # In production, replace this policy with more granular permissions targeting specific log streams.
}

# --- Lambda Interface Endpoint --- #
resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-lambda-endpoint"
    Environment = var.environment
  }
}

# --- CloudWatch Logs Interface Endpoint --- #
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-cloudwatch-logs-endpoint"
    Environment = var.environment
  }
}

# --- SQS Interface Endpoint --- #
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-sqs-endpoint"
    Environment = var.environment
  }
}

# --- KMS Interface Endpoint --- #
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = concat(var.private_subnet_ids, var.public_subnet_ids)
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-kms-endpoint"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. This module creates Interface Endpoints for multiple AWS services including SSM, Lambda, CloudWatch Logs, SQS, and KMS.
#    Gateway Endpoints (S3 and DynamoDB) are managed by the VPC module.
# 2. Security Group for Interface Endpoints allows HTTPS access (port 443) from within the VPC.
# 3. CloudWatch Logs are optional and can be enabled for monitoring traffic.
# 4. Tags are applied consistently across all resources for better identification and management.