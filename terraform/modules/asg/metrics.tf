# --- CloudWatch Alarms for Auto Scaling and Monitoring --- #
# This file defines CloudWatch alarms for monitoring Auto Scaling Group (ASG).
# Alarms are enabled or disabled using individual variables for flexibility.

# --- Scale-Out Alarm --- #
# Adds an instance to the ASG when CPU utilization exceeds the threshold.
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  count = var.enable_scale_out_alarm && var.enable_scaling_policies ? 1 : 0 # Enabled only if scale-out alarm and scaling policies are allowed

  alarm_name          = "${var.name_prefix}-scale-out"
  alarm_description   = "Triggers when CPU utilization exceeds ${var.scale_out_cpu_threshold}% for 5 minutes, causing an additional instance to be added to the ASG."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_actions       = var.enable_scaling_policies ? [aws_autoscaling_policy.scale_out_policy[0].arn] : [] # Trigger the scale-out policy
  ok_actions          = [var.sns_topic_arn]                                                                 # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --- Scale-In Alarm --- #
# Removes an instance from the ASG when CPU utilization falls below the threshold.
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  count = var.enable_scale_in_alarm ? 1 : 0 # Enabled only if scale-in alarm is allowed

  alarm_name          = "${var.name_prefix}-scale-in"
  alarm_description   = "Triggers when CPU utilization falls below ${var.scale_in_cpu_threshold}% for 5 minutes, causing an instance to be removed from the ASG."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_actions       = var.enable_scaling_policies ? [aws_autoscaling_policy.scale_out_policy[0].arn] : [] # Trigger the scale-in policy
  ok_actions          = [var.sns_topic_arn]                                                                 # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --- ASG Instance Health Alarm --- #
# Monitors instance health within ASG using AWS EC2 status checks.
# This alarm is primarily for notifications about system-level issues not covered by ALB health checks.
resource "aws_cloudwatch_metric_alarm" "asg_status_check_failed" {
  count = var.enable_asg_status_check_alarm ? 1 : 0 # Enabled only if ASG status check alarm is allowed

  alarm_name          = "${var.name_prefix}-asg-status-check-failed"
  alarm_description   = "Triggers when an instance in the ASG fails its status checks for 5 minutes, indicating a potential issue with the instance's health."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_actions       = [var.sns_topic_arn] # Notify via SNS topic
  ok_actions          = [var.sns_topic_arn] # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --- High Incoming Network Traffic Alarm --- #
# Detects unusual incoming traffic spikes, potentially indicating DDoS attacks.
resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  count = var.enable_high_network_in_alarm ? 1 : 0 # Enabled only if high network-in alarm is allowed

  alarm_name          = "${var.name_prefix}-high-network-in"
  alarm_description   = "Triggers when incoming network traffic exceeds ${var.network_in_threshold} bytes over a 5-minute period, potentially indicating a DDoS attack or unexpected traffic spike."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2 # The number of datapoints that must be breaching to trigger the alarm.
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_in_threshold
  alarm_actions       = [] # No action configured; for monitoring only
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --- High Outgoing Network Traffic Alarm --- #
# Triggers when outgoing network traffic exceeds the defined threshold.
# Identifies potential data transfer spikes indicating security concerns.
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  count = var.enable_high_network_out_alarm ? 1 : 0 # Enabled only if high network-out alarm is allowed

  alarm_name          = "${var.name_prefix}-high-network-out"
  alarm_description   = "Triggers when outgoing network traffic exceeds ${var.network_out_threshold} bytes over a 5-minute period, potentially indicating data exfiltration or excessive outbound traffic."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2 # The number of datapoints that must be breaching to trigger the alarm.
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_out_threshold
  alarm_actions       = [] # No action configured; for monitoring only
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# --- Notes --- #

# 1. **Alarm Logic**:
#    - Each alarm is enabled or disabled using individual variables (e.g., `enable_scale_out_alarm`).
#
# 2. **Scaling Alarms**:
#    - `scale_out_alarm`: Scales out (adds instances) when CPU utilization exceeds the threshold.
#    - `scale_in_alarm`: Scales in (removes instances) when CPU utilization drops below the threshold.
#
# 3. **Health Monitoring**:
#    - `asg_status_check_failed`: Ensures all instances in ASG pass AWS health checks.
#
# 4. **Traffic Monitoring**:
#    - `high_network_in`: Tracks unusually high incoming traffic.
#    - `high_network_out`: Tracks unusually high outgoing traffic.
#
# 5. **SNS Notifications**:
#    - Critical alarms (e.g., `asg_status_check_failed`) notify via SNS if a topic ARN is provided.
#
# 6. **Scalability**:
#    - Modular design allows easy addition of new alarms and metrics as needed.