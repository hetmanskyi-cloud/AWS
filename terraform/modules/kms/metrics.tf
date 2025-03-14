# --- CloudWatch Alarm for Decrypt Operations --- #
# Creates a CloudWatch Alarm to monitor high Decrypt operation usage on the KMS key.
# Alarm triggers when decrypt operations exceed the defined threshold 'var.key_decrypt_threshold'.
resource "aws_cloudwatch_metric_alarm" "kms_decrypt_alarm" {
  count = var.enable_key_monitoring ? 1 : 0 # Enabled via 'enable_key_monitoring' variable.

  alarm_name = "${var.name_prefix}-kms-decrypt-usage-high-${var.environment}"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 3 # Consecutive periods to evaluate for alarm trigger (increased to reduce false positives).
  datapoints_to_alarm = 2 # Data points breaching threshold within evaluation period to trigger alarm.
  # Note: 'datapoints_to_alarm' with 'evaluation_periods' reduces false alarms from temporary spikes.
  # Example: Alarm triggers if 2 out of 3 evaluation periods exceed threshold.

  metric_name = "DecryptCount"
  namespace   = "AWS/KMS"

  period    = 300 # Evaluation period: 5 minutes.
  statistic = "Sum"
  threshold = var.key_decrypt_threshold

  dimensions = {
    KeyId = aws_kms_key.general_encryption_key.id
  }

  alarm_description = "Alert when KMS decrypt operations exceed threshold."

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : [] # SNS topic ARN for alarm notifications (optional if empty).
  ok_actions    = var.sns_topic_arn != "" ? [var.sns_topic_arn] : [] # SNS topic ARN for OK notifications (optional if empty).

  treat_missing_data = "notBreaching" # Treat missing data points as not breaching the threshold.

  tags = {
    Name        = "${var.name_prefix}-kms-decrypt-usage-high"
    Environment = var.environment
  }
}

# --- Notes --- #
# - Adjust 'threshold' and 'evaluation_periods' based on expected workload patterns and sensitivity.
# - Increasing 'evaluation_periods' and using 'datapoints_to_alarm' helps minimize false positives in production environments.
# - Ensure 'sns_topic_arn' variable is set in 'terraform.tfvars' to enable alarm notifications via SNS topic.
# - Failure to specify SNS ARN will result in no notifications.