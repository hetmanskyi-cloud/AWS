# --- EFS CloudWatch Alarms --- #
# This file defines CloudWatch alarms for monitoring the health and performance of the EFS file system.

# --- Low Burst Credit Balance Alarm --- #
# This alarm monitors the BurstCreditBalance metric, which is critical for file systems
# using the 'bursting' throughput mode. A low balance can lead to performance throttling.
resource "aws_cloudwatch_metric_alarm" "low_burst_credit_balance" {
  # Only relevant for 'bursting' throughput mode, ignored otherwise.
  count = var.enable_burst_credit_alarm && var.throughput_mode == "bursting" ? 1 : 0

  alarm_name          = "${var.name_prefix}-efs-low-burst-credits-${var.environment}"
  alarm_description   = "Triggers when the EFS burst credit balance is low, indicating a risk of performance throttling."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "BurstCreditBalance"
  namespace           = "AWS/EFS"
  period              = 300 # 5 minutes
  statistic           = "Minimum"
  threshold           = var.burst_credit_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FileSystemId = aws_efs_file_system.efs.id
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-efs-low-burst-credits-${var.environment}",
    Type      = "Performance",
    AlertType = "EFS:BurstCredits"
  })
}

# --- Notes --- #
# 1. **BurstCreditBalance**:
#    - This metric is the most important one to monitor for EFS file systems in 'bursting' mode.
#    - File systems accumulate credits during periods of low activity and spend them during bursts of high activity.
#    - If the balance drops to zero, the file system's performance is throttled to its baseline rate,
#      which can severely impact application performance.
#
# 2. **Conditional Creation**:
#    - The alarm is only created if `var.enable_burst_credit_alarm` is true AND the `var.throughput_mode`
#      is set to 'bursting', as this metric is irrelevant for other modes.
#
# 3. **Threshold**:
#    - The `var.burst_credit_threshold` should be set to a value that provides an early warning. The default
#      in `variables.tf` corresponds to approximately 1 TiB of credits. If your balance consistently
#      drops below this, you should consider switching to 'provisioned' or 'elastic' throughput.
