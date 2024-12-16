# --- CloudWatch Alarms for ALB --- #

# --- Alarm for high request count (Only for stage and prod) --- #
# Explanation: Tracks high traffic on the ALB. Useful for scaling or debugging.
resource "aws_cloudwatch_metric_alarm" "alb_high_request_count" {
  count = var.environment != "dev" ? 1 : 0 # Active only for stage and prod

  alarm_name          = "${var.name_prefix}-alb-high-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_request_count_threshold
  alarm_actions       = var.environment == "prod" ? [var.sns_topic_arn] : [] # Only notify in prod
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# --- Alarm for 5XX errors (Only for stage and prod) --- #
# Explanation: Catches HTTP 5xx errors, often caused by application or server failures.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.environment != "dev" ? 1 : 0 # Active only for stage and prod

  alarm_name          = "${var.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_actions       = [var.sns_topic_arn] # Notify for stage and prod
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
  alarm_actions       = [var.sns_topic_arn] # Notify in all environments
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
    TargetGroup  = aws_lb_target_group.wordpress.arn_suffix
  }
}

# --- Notes ---#

# Minimizing alerts in test environments (dev, stage):

# In dev, experiments often trigger temporary errors. Alerts in this environment add unnecessary noise and are handled manually during testing.
# In stage, metrics are used for load testing and analysis, but alerts are unnecessary since monitoring is performed manually during the test phase.

# Centralizing critical alerts in prod:
# In prod, alerts are essential for immediate response to incidents that affect real users.

# Notifications are enabled only in prod to reduce noise in non-critical environments and ensure alerts are focused on critical issues.