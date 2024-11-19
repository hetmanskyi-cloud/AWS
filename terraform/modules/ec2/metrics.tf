# --- CloudWatch Alarms for Auto Scaling --- #

# Alarm for scaling out (add instance when CPU > threshold)
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "${var.name_prefix}-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn] # Scale-out policy ARN
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }
}

# Alarm for scaling in (remove instance when CPU < threshold)
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "${var.name_prefix}-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_in_policy.arn] # Scale-in policy ARN
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }
}

# Alarm for high incoming network traffic
resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  alarm_name          = "${var.name_prefix}-high-network-in"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_in_threshold
  alarm_actions       = [] # Alarm without action
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }
}

# Alarm for high outgoing network traffic
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  alarm_name          = "${var.name_prefix}-high-network-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_out_threshold
  alarm_actions       = [] # Alarm without action
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }
}

# Alarm for EC2 instance status check failure
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.name_prefix}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_actions       = [var.sns_topic_arn] # SNS topic for notifications
  dimensions = {
    InstanceId = aws_autoscaling_group.ec2_asg.id
  }
}