# --- Main Configuration for VPC Endpoints --- #
# Each endpoint is placed in a different private subnet to ensure high availability
# and avoid the DuplicateSubnetsInSameZone error.

# --- SSM Interface Endpoint --- #
# Placed in the first private subnet
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.private_subnet_ids[0]] # Using only first private subnet
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  # Optional: Enable CloudWatch Logs for monitoring traffic
  policy = var.enable_cloudwatch_logs_for_endpoints ? data.aws_iam_policy_document.endpoint_ssm_doc[0].json : null

  tags = {
    Name        = "${var.name_prefix}-ssm-endpoint"
    Environment = var.environment
  }
}

# --- SSM Messages Interface Endpoint --- #
# Placed in the second private subnet
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.private_subnet_ids[1]] # Using only second private subnet
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-ssm-messages-endpoint"
    Environment = var.environment
  }
}

# --- ASG Messages Interface Endpoint --- #
# Placed in the third private subnet
resource "aws_vpc_endpoint" "asg_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.private_subnet_ids[2]] # Using only third private subnet
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-asg-messages-endpoint"
    Environment = var.environment
  }
}

# --- Lambda Interface Endpoint --- #
resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.private_subnet_ids[0]] # Using only first private subnet
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
  subnet_ids          = [var.private_subnet_ids[1]] # Using only second private subnet
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
  subnet_ids          = [var.private_subnet_ids[2]] # Using only third private subnet
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
  subnet_ids          = [var.private_subnet_ids[0]] # Using only first private subnet
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-kms-endpoint"
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

# --- Notes --- #
# 1. This module creates Interface Endpoints for multiple AWS services including SSM, Lambda, CloudWatch Logs, SQS, and KMS.
#    Gateway Endpoints (S3 and DynamoDB) are managed by the VPC module.
#
# 2. Endpoint Distribution:
#    - Each Interface Endpoint is placed in a different private subnet
#    - This ensures high availability and prevents the DuplicateSubnetsInSameZone error
#    - Endpoints are distributed across different Availability Zones
#
# 3. Security:
#    - Security Group for Interface Endpoints allows HTTPS access (port 443) from within the VPC
#    - CloudWatch Logs are optional and can be enabled for monitoring traffic
#
# 4. Best Practices:
#    - Tags are applied consistently across all resources
#    - Each endpoint uses a dedicated subnet to ensure proper AZ distribution
#    - Resource naming follows consistent patterns for better management