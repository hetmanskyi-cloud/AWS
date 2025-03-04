# --- CloudWatch Alarm for Decrypt Operations --- #
# This resource creates a CloudWatch Alarm to monitor high usage of the Decrypt operation on the KMS key.
# The alarm is triggered when the number of decrypt operations exceeds the threshold defined in `var.key_decrypt_threshold`.
resource "aws_cloudwatch_metric_alarm" "kms_decrypt_alarm" {
  count = var.enable_key_monitoring ? 1 : 0 # Conditional creation based on the `enable_key_monitoring` variable.

  # Name of the CloudWatch Alarm
  alarm_name = "${var.name_prefix}-kms-decrypt-usage-high-${var.environment}"

  # Operator used for comparing the metric and threshold
  comparison_operator = "GreaterThanThreshold"

  # Number of consecutive evaluation periods the metric must meet the threshold condition to trigger the alarm
  evaluation_periods  = 3 # Increased to reduce false positives
  datapoints_to_alarm = 2 # Number of breaching datapoints within the evaluation period to trigger the alarm
  # Note: Using `datapoints_to_alarm` ensures that temporary spikes in usage do not trigger false positives.
  # Example: With `evaluation_periods = 3` and `datapoints_to_alarm = 2`,
  # the alarm triggers only if 2 out of 3 evaluation periods exceed the threshold.

  # Metric name and namespace to monitor KMS decrypt operations
  metric_name = "DecryptCount"
  namespace   = "AWS/KMS"

  # The time period (in seconds) over which the metric is evaluated
  period = 300 # 5 minutes

  # Statistical function to apply to the metric
  statistic = "Sum"

  # Threshold value for the metric
  threshold = var.key_decrypt_threshold

  # Dimension for the CloudWatch Alarm to monitor a specific KMS key
  dimensions = {
    KeyId = aws_kms_key.general_encryption_key.id
  }

  # Description of the alarm
  alarm_description = "Alert when decrypt operations exceed the threshold."

  # Actions to perform when the alarm state changes
  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : [] # Avoid errors if sns_topic_arn is empty

  # Actions to perform when the alarm state returns to OK
  ok_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : [] # Avoid errors if sns_topic_arn is empty

  # Treat missing data as missing (default behavior)
  treat_missing_data = "notBreaching"

  tags = {
    Name        = "${var.name_prefix}-kms-decrypt-usage-high"
    Environment = var.environment
  }

  # --- Comments for clarity --- #
  # This alarm monitors high usage of the Decrypt operation on the KMS key.
  # It is triggered when the number of decrypt operations exceeds the threshold.

  # Note: The threshold and evaluation periods should be adjusted based on observed workload patterns.
  # Increasing `evaluation_periods` and using `datapoints_to_alarm` helps reduce false positives in production.

  # Ensure `sns_topic_arn` is set to receive alarm notifications.
  # If left empty, alarm actions will not send notifications.
}