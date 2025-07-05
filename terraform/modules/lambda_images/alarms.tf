# --- CloudWatch Alarms for Lambda Function --- #
# This file defines a set of standard CloudWatch alarms to monitor the health
# and performance of the Lambda function.

# --- Helper Local Variable for Alarm Actions --- #
# This local variable simplifies the management of alarm actions.
# It ensures that alarms are only sent to an SNS topic if its ARN is provided.
locals {
  # Use the provided SNS topic ARN if it's not null, otherwise use an empty list.
  alarm_actions = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
}

# --- Lambda Errors Alarm --- #
# This alarm triggers if the number of function errors exceeds the defined threshold.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  # Create this alarm only if alarms are enabled via the variable.
  count = var.alarms_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-${var.lambda_function_name}-errors-alarm-${var.environment}"
  alarm_description   = "Triggers when the Lambda function has an excessive number of errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.error_alarm_threshold
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  # Send notification to the specified SNS topic. Also notify when the alarm state returns to OK.
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-errors-alarm-${var.environment}"
  })
}

# --- Lambda Throttles Alarm --- #
# This alarm triggers if the number of throttled invocations exceeds the threshold.
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  # Create this alarm only if alarms are enabled.
  count = var.alarms_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-${var.lambda_function_name}-throttles-alarm-${var.environment}"
  alarm_description   = "Triggers when the Lambda function invocations are being throttled."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.throttles_alarm_threshold
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  # Send notification to the specified SNS topic.
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-throttles-alarm-${var.environment}"
  })
}

# --- Lambda Duration Alarm --- #
# This alarm triggers if the function's execution time (p95 percentile) exceeds the threshold.
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  # Create this alarm only if alarms are enabled.
  count = var.alarms_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-${var.lambda_function_name}-duration-alarm-${var.environment}"
  alarm_description   = "Triggers when the Lambda function p95 duration is too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.duration_alarm_threshold_ms
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"

  # Using p95 extended statistic is more reliable than average for detecting performance issues.
  extended_statistic = "p95"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  # Send notification to the specified SNS topic.
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-duration-alarm-${var.environment}"
  })
}

# --- Notes --- #
# 1. Conditional Creation: All alarms are created only if `var.alarms_enabled` is set to `true`.
# 2. Key Metrics Monitored: The module sets up alarms for three critical Lambda metrics:
#    - `Errors` (Sum): Tracks the total number of failed invocations.
#    - `Throttles` (Sum): Tracks rejected invocations due to concurrency limits.
#    - `Duration` (p95): Tracks the 95th percentile of execution time, which is a robust indicator of performance degradation.
# 3. Notifications: Alarm notifications are sent to the SNS topic specified in `var.alarm_sns_topic_arn`. If the variable is null, no notifications are configured.
#    `ok_actions` is also configured to notify when the function's state returns to normal.
