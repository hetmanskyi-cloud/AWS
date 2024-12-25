# --- CloudWatch Alarms for EC2 Auto Scaling and Monitoring --- #
# This file defines CloudWatch alarms for monitoring EC2 instances and Auto Scaling Group (ASG).
# Alarms are enabled or disabled based on the environment using conditional logic.

# --- Scale-Out Alarm --- #
# Triggers when CPU utilization exceeds the defined threshold, adding an instance to the ASG.
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage/prod
  alarm_name          = "${var.name_prefix}-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy[0].arn] # Trigger the scale-out policy
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg[0].name
  }
}

# --- Scale-In Alarm --- #
# Triggers when CPU utilization drops below the defined threshold, removing an instance from the ASG.
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage/prod
  alarm_name          = "${var.name_prefix}-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_in_policy[0].arn] # Trigger the scale-in policy
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg[0].name
  }
}

# --- Instance Status Check Alarm --- #
# Monitors health of the standalone EC2 instance (instance_image).
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.name_prefix}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_actions       = var.environment != "dev" ? [var.sns_topic_arn] : [] # Notify only in stage/prod
  dimensions = {
    InstanceId = aws_instance.instance_image[0].id
  }
}

# --- Instance Status Check Alarm for Auto Scaling Group --- #
# Monitors health of EC2 instances within the Auto Scaling Group in stage/prod.
resource "aws_cloudwatch_metric_alarm" "asg_status_check_failed" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage/prod
  alarm_name          = "${var.name_prefix}-asg-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_actions       = [var.sns_topic_arn] # Notify via SNS topic
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg[0].name
  }
}

# --- High Incoming Network Traffic Alarm --- #
# Triggers when incoming network traffic exceeds the defined threshold (enabled in stage/prod).
resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage/prod
  alarm_name          = "${var.name_prefix}-high-network-in"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_in_threshold
  alarm_actions       = [] # No action configured; for monitoring only
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg[0].name
  }
}

# --- High Outgoing Network Traffic Alarm --- #
# Triggers when outgoing network traffic exceeds the defined threshold (enabled in stage/prod).
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage/prod
  alarm_name          = "${var.name_prefix}-high-network-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_out_threshold
  alarm_actions       = [] # No action configured; for monitoring only
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg[0].name
  }
}

# --- Notes --- #
# 1. **Environment Logic**:
#    - `dev`: Includes basic alarms for instance health (`status_check_failed`).
#    - `stage/prod`: Adds alarms for scaling (`scale_out_alarm`, `scale_in_alarm`) and monitoring network traffic (`high_network_in`, `high_network_out`).
#
# 2. **Scaling Alarms**:
#    - `scale_out_alarm`: Automatically scales out (adds instances) when CPU utilization exceeds the threshold.
#    - `scale_in_alarm`: Automatically scales in (removes instances) when CPU utilization drops below the threshold.
#
# 3. **Health Monitoring**:
#    - `status_check_failed`: Monitors the standalone instance (`instance_image`).
#    - `asg_status_check_failed`: Ensures all instances in ASG pass AWS health checks in stage/prod.
#
# 4. **Traffic Monitoring**:
#    - `high_network_in`: Tracks unusually high incoming traffic for detecting DDoS attacks or scaling needs.
#    - `high_network_out`: Tracks unusually high outgoing traffic for identifying data transfer spikes or potential security issues.
#
# 5. **Best Practices**:
#    - Configure SNS notifications for critical alarms in stage/prod to alert the appropriate teams.
#    - Set realistic thresholds for scaling and traffic alarms based on workload patterns and expected traffic.
#
# 6. **Scalability**:
#    - This configuration is modular and easily extendable. Add more alarms as needed for additional metrics in stage/prod environments.
# 7. **CloudWatch Logs Integration**:
#    - Consider exporting alarms to CloudWatch Logs for long-term analysis and troubleshooting.