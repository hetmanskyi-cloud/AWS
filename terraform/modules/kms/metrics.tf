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

# --- CloudWatch Alarm for KMS AccessDenied Errors --- #
# Creates a CloudWatch Alarm to detect AccessDenied errors on the KMS key (e.g., due to invalid IAM policies or misuse).
# Helps detect unauthorized access or misconfigured services attempting to use the key.
resource "aws_cloudwatch_metric_alarm" "kms_access_denied_alarm" {
  count = var.enable_kms_access_denied_alarm ? 1 : 0

  alarm_name          = "${var.name_prefix}-kms-access-denied-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0

  metric_name = "AccessDenied"
  namespace   = "AWS/KMS"
  statistic   = "Sum"
  period      = 300 # 5 minutes

  dimensions = {
    KeyId = aws_kms_key.general_encryption_key.id
  }

  alarm_description = "Triggers when there are any KMS AccessDenied errors — possible unauthorized or misconfigured access."

  treat_missing_data = "notBreaching"
  alarm_actions      = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  ok_actions         = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.name_prefix}-kms-access-denied"
    Environment = var.environment
  }
}

# --- Notes --- #
# - Includes alarms for DecryptCount (high usage) and AccessDenied (unauthorized attempts).
# - 'threshold', 'evaluation_periods', and 'datapoints_to_alarm' are tuned to reduce false positives.
# - SNS notifications are enabled via 'sns_topic_arn' (set in terraform.tfvars).
# - If 'sns_topic_arn' is empty, alarms will trigger silently (no email or alert).