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
      "kms:DescribeKey",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
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

# Attach the CloudWatchLogsFullAccess policy to enable CloudWatch access
resource "aws_iam_role_policy_attachment" "vpc_flow_logs_cloudwatch_policy" {
  role       = aws_iam_role.vpc_flow_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Attach custom KMS policy to IAM Role for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "${var.name_prefix}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs_role.name
  policy = data.aws_iam_policy_document.vpc_flow_logs_kms_policy.json
}

# --- CloudWatch Log Group for VPC Flow Logs --- #

# Create CloudWatch log group to store VPC Flow Logs with specified retention and encryption settings
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name              = "/aws/vpc/flow-logs/${var.name_prefix}"
  retention_in_days = var.log_retention_in_days # Set retention policy for log data
  kms_key_id        = var.kms_key_arn           # Use KMS key for log encryption

  tags = {
    Name        = "${var.name_prefix}-flow-logs"
    Environment = var.environment
  }

  # Lifecycle configuration to allow forced deletion
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [retention_in_days, kms_key_id]
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

  depends_on = [aws_cloudwatch_log_group.vpc_log_group]

  tags = {
    Name        = "${var.name_prefix}-vpc-flow-log"
    Environment = var.environment
  }
}