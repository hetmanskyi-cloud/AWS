# --- DynamoDB Table CloudWatch Alarms --- #
# These alarms monitor the health and performance of the DynamoDB table,
# focusing on throttling and system-level errors.

# --- Alarm: Throttled Write Requests --- #
# This alarm triggers if the number of throttled write requests exceeds a
# threshold, indicating that the provisioned write capacity is insufficient.
resource "aws_cloudwatch_metric_alarm" "throttled_writes" {
  count = var.cloudwatch_alarms_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name_prefix}-${var.dynamodb_table_name}-throttled-writes-alarm-${var.environment}"
  alarm_description   = "Alarm that triggers when write requests to the ${var.dynamodb_table_name} table are throttled."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5 # Trigger if more than 5 write requests are throttled in 5 minutes

  # Metric Definition
  namespace   = "AWS/DynamoDB"
  metric_name = "ThrottledRequests"
  statistic   = "Sum"
  period      = 300 # 5 minutes

  dimensions = {
    TableName = aws_dynamodb_table.dynamodb_table.name
    Operation = "PutItem" # We are specifically monitoring write operations
  }

  # Notification Actions
  alarm_actions = [var.cloudwatch_alarms_topic_arn]
  ok_actions    = [var.cloudwatch_alarms_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.dynamodb_table_name}-throttled-writes-alarm-${var.environment}"
  })
}

# --- Alarm: System Errors --- #
# This alarm triggers on any system-level errors returned by DynamoDB,
# which could indicate an issue with the AWS service itself.
resource "aws_cloudwatch_metric_alarm" "system_errors" {
  count = var.cloudwatch_alarms_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name_prefix}-${var.dynamodb_table_name}-system-errors-alarm-${var.environment}"
  alarm_description   = "Alarm that triggers on any system errors for the ${var.dynamodb_table_name} table."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0 # Trigger on any single system error

  # Metric Definition
  namespace   = "AWS/DynamoDB"
  metric_name = "SystemErrors"
  statistic   = "Sum"
  period      = 300

  dimensions = {
    TableName = aws_dynamodb_table.dynamodb_table.name
  }

  # Notification Actions
  alarm_actions = [var.cloudwatch_alarms_topic_arn]
  ok_actions    = [var.cloudwatch_alarms_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.dynamodb_table_name}-system-errors-alarm-${var.environment}"
  })
}

# --- Notes --- #
# 1. Throttling vs. System Errors:
#    - The `ThrottledRequests` alarm is the most critical for performance tuning. It's the
#      primary indicator that you need to adjust Provisioned Throughput or check your
#      On-Demand capacity settings.
#    - The `SystemErrors` alarm is for service health. It's rare but essential for
#      detecting underlying issues with the DynamoDB service.
#
# 2. Granularity: The throttling alarm is configured to monitor only `PutItem`
#    operations, as this is the primary write action performed by the Lambda function.
#    This provides more specific and actionable alerts.
#
# 3. Conditional Creation: Alarms are only created if the `cloudwatch_alarms_topic_arn`
#    variable is provided, keeping the monitoring feature optional and modular.
