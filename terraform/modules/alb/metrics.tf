# --- CloudWatch Alarms for ALB --- #

# --- Alarm for high request count --- #
# Explanation: Tracks high traffic on the ALB. Useful for scaling or debugging.
resource "aws_cloudwatch_metric_alarm" "alb_high_request_count" {
  count = var.enable_high_request_alarm ? 1 : 0 # Controlled by the variable `enable_high_request_alarm`

  alarm_name          = "${var.name_prefix}-alb-high-request-count-${var.environment}"
  alarm_description   = "Triggers when the number of requests exceeds the defined threshold. This may indicate unexpected traffic patterns or potential DDoS attacks."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_request_count_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn] # Notifications are always enabled if the resource is activated
  ok_actions          = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# --- Alarm for 5XX errors --- #
# Explanation: Catches HTTP 5xx errors, often caused by application or server failures.
# alb_5xx_errors: Indicates application or target instance errors (5XX returned by ASG targets).
# Investigate application logs or instance health to identify the root cause.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.enable_5xx_alarm ? 1 : 0 # Controlled by the variable `enable_5xx_alarm`

  alarm_name          = "${var.name_prefix}-alb-5xx-errors-${var.environment}"
  alarm_description   = "Monitors HTTP 5XX errors which indicate server-side issues. High error rates may signal application problems or infrastructure issues."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn] # Notifications are always enabled if the resource is activated
  ok_actions          = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# --- Alarm for Target Response Time --- #
# Explanation: Monitors the average response time of targets in the ALB Target Group.
# High response time indicates potential issues with the application (WordPress) or instance overload.
# Useful for detecting slow database queries or insufficient compute resources.
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = var.enable_target_response_time_alarm ? 1 : 0 # Controlled by the variable `enable_target_response_time_alarm`

  alarm_name          = "${var.name_prefix}-alb-target-response-time-${var.environment}"
  alarm_description   = "Alerts when the average response time from targets exceeds 1 second, which may indicate performance degradation."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0 # Example threshold in seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
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
  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets-${var.environment}"
  alarm_description   = "Alerts when any target becomes unhealthy, helping to quickly identify and resolve application or infrastructure issues."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0 # Triggered if at least one unhealthy target
  treat_missing_data  = "notBreaching"
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
#
# Always-On Alarm:
# - The `alb_unhealthy_host_count` alarm is always created to ensure health monitoring of target instances.
# - This alarm quickly notifies when any instance behind the ALB becomes unhealthy according to the ALB health check.
# - Helps detect issues like WordPress crash, MySQL connection failure, or instance termination.
#
# Simplified Notification Logic:
# - Notifications are always enabled for each alarm if the resource is created.
# - Alerts are delivered to the specified SNS topic (`var.sns_topic_arn`).
#
# Key Metrics:
# - `RequestCount`: Monitors high traffic for scaling or debugging.
# - `HTTPCode_Target_5XX_Count`: Detects server/application-level errors.
# - `TargetResponseTime`: Measures average target response time; high values indicate potential application or infrastructure bottlenecks.
# - `UnHealthyHostCount`: Tracks the health status of target instances.
#
# - Note: 5XX errors may originate from the ALB itself or backend targets. The metric "HTTPCode_Target_5XX_Count" specifically monitors target (ASG) errors.
#
# Recommendations:
# - Regularly review and adjust alarm thresholds (`alb_request_count_threshold`, `alb_5xx_threshold`) to align with application needs.
# - Periodically verify that the SNS topic is configured correctly to receive alerts.
#
# Threshold Validation:
# - Ensure that `alb_request_count_threshold` and `alb_5xx_threshold` are tuned to real application requirements
#   to avoid false positives or missing critical events.
#
# Notifications Consistency:
# - Double-check that all alarms correctly reference `sns_topic_arn` to ensure alerts are reliably sent to the right channel.
