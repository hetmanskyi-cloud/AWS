# --- CloudWatch Alarms for ALB --- #

# Alarm for high request count
resource "aws_cloudwatch_metric_alarm" "alb_high_request_count" {
  alarm_name          = "${var.name_prefix}-alb-high-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_request_count_threshold
  alarm_actions       = [] # Alarm without action
  dimensions = {
    LoadBalancer = var.alb_name
  }
}

# Alarm for 5XX errors from targets
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_actions       = [var.sns_topic_arn] # SNS topic for notifications
  dimensions = {
    LoadBalancer = var.alb_name
  }
}
