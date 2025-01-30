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

# Policy granting minimal permissions for VPC Flow Logs to write logs to CloudWatch.
# tfsec:ignore:aws-iam-no-policy-wildcards
# Wildcards are required because VPC Flow Logs dynamically creates log streams.
data "aws_iam_policy_document" "vpc_flow_logs_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.vpc_log_group.arn,
      "${aws_cloudwatch_log_group.vpc_log_group.arn}:*"
    ]
  }
}

# Attach custom KMS policy to IAM Role for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "${var.name_prefix}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs_role.name
  policy = data.aws_iam_policy_document.vpc_flow_logs_cloudwatch_policy.json
}

# --- CloudWatch Log Group for VPC Flow Logs --- #

# Create CloudWatch log group to store VPC Flow Logs with specified retention and encryption settings
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name              = "/aws/vpc/flow-logs/${var.name_prefix}"
  retention_in_days = var.flow_logs_retention_in_days # Set retention policy for log data
  kms_key_id        = var.kms_key_arn                 # Use KMS key for CloudWatch log encryption

  tags = {
    Name        = "${var.name_prefix}-flow-logs"
    Environment = var.environment
  }

  # Lifecycle configuration to allow forced deletion
  lifecycle {
    prevent_destroy = false
  }
}

# --- VPC Flow Log Configuration --- #

# Configure VPC Flow Log to send logs to CloudWatch with the associated IAM role and log group
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
# 1. The IAM Role for VPC Flow Logs is configured with minimal permissions for security,
#    ensuring only the necessary actions for CloudWatch and KMS are allowed.
# 2. KMS encryption is used to securely store log data in CloudWatch Logs.
# 3. The CloudWatch Log Group must exist before the VPC Flow Logs configuration is applied.
# 4. Lifecycle configuration allows deletion of logs and resources when necessary (`prevent_destroy = false`).
# 5. The log retention period is configurable via `var.flow_logs_retention_in_days`.
# 6. Ensure `iam_role_arn` is correctly associated to enable log delivery to CloudWatch.