# --- IAM Policies for VPC Flow Logs --- #

# Create IAM policy document to allow the VPC Flow Logs service to assume the role
data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# IAM policy document for KMS permissions required by VPC Flow Logs
data "aws_iam_policy_document" "vpc_flow_logs_kms_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncryptTo",
      "kms:ReEncryptFrom",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

# --- IAM Role and Policies --- #

# Create IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs_role" {
  name               = "${var.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags = {
    Name        = "${var.name_prefix}-vpc-flow-logs-role"
    Environment = var.environment
  }
}

# IAM policy document for CloudWatch Logs permissions
data "aws_iam_policy_document" "vpc_flow_logs_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/flow-logs/${var.environment}:*",
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/flow-logs/${var.environment}"
    ]
  }
}

# Attach custom KMS policy to IAM Role for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "${var.name_prefix}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs_role.name
  policy = data.aws_iam_policy_document.vpc_flow_logs_cloudwatch_policy.json
}

# --- VPC Flow Logs Configuration --- #
# This configuration manages VPC Flow Logs with CloudWatch integration
# Key components:
# - IAM roles and policies for secure log delivery
# - CloudWatch Log Group with KMS encryption
# - VPC Flow Log with ALL traffic capture

# --- CloudWatch Log Group for VPC Flow Logs --- #
# Create CloudWatch log group with:
# - Configurable retention period
# - KMS encryption for security
# - Automatic cleanup on resource deletion
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = var.flow_logs_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.name_prefix}-flow-logs"
    Environment = var.environment
  }

  depends_on = [var.kms_key_arn] # Явная зависимость от KMS ключа

  # Lifecycle configuration to allow forced deletion
  lifecycle {
    prevent_destroy = false
  }
}

# --- VPC Flow Log Configuration --- #
# Configure VPC Flow Log to:
# - Capture ALL traffic types (ACCEPT/REJECT)
# - Send logs to CloudWatch Logs
# - Use IAM role for secure delivery
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.vpc_log_group.arn
  traffic_type         = "ALL"              # Capture all traffic (accepted, rejected, and all)
  vpc_id               = aws_vpc.vpc.id     # Specify the VPC ID
  log_destination_type = "cloud-watch-logs" # Set destination to CloudWatch Logs
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  # Prevents Terraform from blocking the destroy action on this resource
  # This allows deletion of the Flow Log resource without restrictions if necessary
  lifecycle {
    prevent_destroy = false
  }

  # The "depends_on" ensures that the CloudWatch Log Group is created before configuring the VPC Flow Logs.
  depends_on = [aws_cloudwatch_log_group.vpc_log_group]

  tags = {
    Name        = "${var.name_prefix}-vpc-flow-log"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. Security and Permissions:
#    - IAM role uses principle of least privilege
#    - KMS encryption protects sensitive log data
#    - CloudWatch permissions are scoped to specific log group
#
# 2. Log Configuration:
#    - Captures ALL traffic (accepted and rejected)
#    - Retention period is configurable via var.flow_logs_retention_in_days
#    - Logs are organized by environment for better management
#
# 3. Resource Management:
#    - CloudWatch Log Group is created before Flow Logs
#    - prevent_destroy = false allows cleanup in test environments
#    - Resources are properly tagged for cost allocation
#
# 4. Best Practices:
#    - Review log retention periods regularly
#    - Monitor CloudWatch costs
#    - Consider sampling in high-traffic environments
#
# 5. Dependencies:
#    - Requires valid KMS key for encryption
#    - IAM role must be properly configured
#    - VPC must exist before enabling flow logs