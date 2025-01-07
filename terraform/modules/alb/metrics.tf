# --- CloudWatch Alarms for ALB --- #

# --- Alarm for high request count --- #
# Explanation: Tracks high traffic on the ALB. Useful for scaling or debugging.
resource "aws_cloudwatch_metric_alarm" "alb_high_request_count" {
  count = var.enable_high_request_alarm ? 1 : 0 # Controlled by the variable `enable_high_request_alarm`

  alarm_name          = "${var.name_prefix}-alb-high-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_request_count_threshold
  alarm_actions       = [var.sns_topic_arn] # Notifications are always enabled if the resource is activated
  ok_actions          = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# --- Alarm for 5XX errors --- #
# Explanation: Catches HTTP 5xx errors, often caused by application or server failures.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.enable_5xx_alarm ? 1 : 0 # Controlled by the variable `enable_5xx_alarm`

  alarm_name          = "${var.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_actions       = [var.sns_topic_arn] # Notifications are always enabled if the resource is activated
  ok_actions          = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# --- Alarm for unhealthy targets --- #
# This alarm triggers if at least one target in the target group becomes unhealthy.
# It's useful for immediate action in case of application or infrastructure issues.
# Explanation: Triggers if any target in the group is unhealthy. Helps in quick debugging.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host_count" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0                   # Triggered if at least one unhealthy target
  alarm_actions       = [var.sns_topic_arn] # Notifications are always enabled
  ok_actions          = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
    TargetGroup  = aws_lb_target_group.wordpress.arn_suffix
  }
}

# --- Notes --- #

# Dynamic Alarm Creation:
# - Alarms for high request count and 5XX errors are conditionally created based on:
#   - `enable_high_request_alarm`: Controls high request count alarms.
#   - `enable_5xx_alarm`: Controls 5XX error alarms.

# Always-On Alarm:
# - The `alb_unhealthy_host_count` alarm is always created to ensure health monitoring of target instances.

# Simplified Notification Logic:
# - Notifications are always enabled for each alarm if the resource is created.
# - Alerts are delivered to the specified SNS topic (`var.sns_topic_arn`).

# Key Metrics:
# - `RequestCount`: Monitors high traffic for scaling or debugging.
# - `HTTPCode_Target_5XX_Count`: Detects server/application-level errors.
# - `UnHealthyHostCount`: Tracks the health status of target instances.

# Recommendations:
# - Regularly review and adjust alarm thresholds (`alb_request_count_threshold`, `alb_5xx_threshold`) to align with application needs.
# - Periodically verify that the SNS topic is configured correctly to receive alerts.