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

# --- IAM Role and Policies --- #

# Create IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs_role" {
  name               = "${var.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-logs-role"
  })
}

# IAM policy document for CloudWatch Logs permissions
data "aws_iam_policy_document" "vpc_flow_logs_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/flow-logs/${var.environment}:*",
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/flow-logs/${var.environment}"
    ]
  }
}

# Attach CloudWatch Logs policy to IAM Role for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "${var.name_prefix}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs_role.name
  policy = data.aws_iam_policy_document.vpc_flow_logs_cloudwatch_policy.json
}

# --- CloudWatch Log Group for VPC Flow Logs --- #
# Create CloudWatch log group with:
# - Configurable retention period
# - KMS encryption for security
# - Automatic cleanup on resource deletion
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = var.flow_logs_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-flow-logs"
  })

  depends_on = [var.kms_key_arn]

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

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-log"
  })
}

# --- CloudWatch Alarm for VPC Flow Logs Delivery Errors --- #
# Monitors 'DeliveryErrors' metric to detect issues with Flow Logs delivery to CloudWatch.
resource "aws_cloudwatch_metric_alarm" "vpc_flow_logs_delivery_errors" {
  alarm_name          = "${var.name_prefix}-vpc-flow-logs-delivery-errors"
  alarm_description   = "Triggers if VPC Flow Logs fail to deliver logs to CloudWatch."
  comparison_operator = "GreaterThanThreshold" # Alarm triggers if delivery errors > 0
  evaluation_periods  = 1                      # Single evaluation period
  metric_name         = "DeliveryErrors"       # Metric to monitor
  namespace           = "AWS/Logs"             # Metric namespace
  period              = 300                    # 5-minute period
  statistic           = "Sum"                  # Sum of delivery errors in the period
  threshold           = 0                      # Any error triggers the alarm

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.vpc_log_group.name # Target VPC Flow Logs log group
  }

  alarm_actions = [var.sns_topic_arn] # Optional: SNS topic for notifications
  ok_actions    = [var.sns_topic_arn] # Optional: Notify when alarm clears

  treat_missing_data = "missing" # Do not evaluate missing data (avoids false alarms)

  tags_all = merge(var.tags, {
    Name = "${var.name_prefix}-flow-logs-delivery-alarm"
  })

  # Notes:
  # 1. Monitors CloudWatch delivery failures for VPC Flow Logs.
  # 2. Triggers if Flow Logs fail to write data (critical visibility issue).
  # 3. Recommended to subscribe SNS topic to email or other notification channels.
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
# 4. Dependencies:
#    - Requires valid KMS key for encryption
#    - IAM role must be properly configured
#    - VPC must exist before enabling flow logs
#
# 5. KMS Usage:
#    - Ensure the KMS key policy allows CloudWatch Logs service principal to use the key.
#    - Recommended: explicitly add `logs.${var.aws_region}.amazonaws.com` principal to the KMS policy.
#
# 6. Best Practices:
#    - Review log retention periods regularly
#    - Monitor CloudWatch costs
#    - Consider sampling in high-traffic environments
#    - Monitor 'DeliveryErrors' CloudWatch metric to detect log delivery failures.