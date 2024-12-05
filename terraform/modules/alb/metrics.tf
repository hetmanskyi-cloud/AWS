# --- CloudWatch Alarms for ALB --- #

# # Alarm for high request count (Commented out for now)
# resource "aws_cloudwatch_metric_alarm" "alb_high_request_count" {
#   alarm_name          = "${var.name_prefix}-alb-high-request-count"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "RequestCount"
#   namespace           = "AWS/ApplicationELB"
#   period              = 300
#   statistic           = "Sum"
#   threshold           = var.alb_request_count_threshold
#   alarm_actions       = [] # Alarm without action
#   dimensions = {
#     LoadBalancer = aws_lb.application.arn_suffix
#   }
# }

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
    LoadBalancer = aws_lb.application.arn_suffix
  }
}

# Alarm for unhealthy targets in ALB
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host_count" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0 # If there is at least one unhealthy target
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
    TargetGroup  = aws_lb_target_group.wordpress.arn_suffix
  }
}
