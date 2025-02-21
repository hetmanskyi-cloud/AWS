# --- Main Configuration for VPC Endpoints --- #
# Create Interface Endpoints for multiple AWS services (SSM, Lambda, CloudWatch Logs, SQS, KMS, etc.)
# Each endpoint is placed in *all* private subnets to ensure high availability,
# so any instance in any AZ can connect to these services privately (without NAT).

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"

  # Important: specify *all* private subnets so that each AZ has ENI
  subnet_ids          = var.private_subnet_ids
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
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.name_prefix}-ssm-messages-endpoint"
    Environment = var.environment
  }
}

# --- ASG Messages Interface Endpoint --- #
resource "aws_vpc_endpoint" "asg_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
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
  subnet_ids          = var.private_subnet_ids
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
  subnet_ids          = var.private_subnet_ids
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
  subnet_ids          = var.private_subnet_ids
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
  subnet_ids          = var.private_subnet_ids
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
# 1. This module creates Interface Endpoints for multiple AWS services such as SSM, SSM Messages,
#    EC2 Messages, Lambda, CloudWatch Logs, SQS, and KMS.
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