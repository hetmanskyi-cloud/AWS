# --- CloudWatch Alarms for Auto Scaling and Monitoring --- #
# This file defines CloudWatch alarms for monitoring Auto Scaling Group (ASG).
# Alarms are enabled or disabled using individual variables for flexibility.

# --- Scale-Out Alarm --- #
# Adds an instance to the ASG when CPU utilization exceeds the threshold.
# Recommended: Enable this in production environments to automatically scale out under high load.
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  count = var.enable_scale_out_alarm && var.enable_scaling_policies ? 1 : 0 # Enabled only if scale-out alarm and scaling policies are allowed

  alarm_name          = "${var.name_prefix}-scale-out-${var.environment}"
  alarm_description   = "Triggers when CPU utilization exceeds ${var.scale_out_cpu_threshold}% for 5 minutes, causing an additional instance to be added to the ASG."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.enable_scaling_policies ? [aws_autoscaling_policy.scale_out_policy[0].arn] : [] # Trigger the scale-out policy
  ok_actions          = [var.sns_topic_arn]                                                                 # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-scale-out-${var.environment}"
    Type      = "CPU"
    AlertType = "ASG:ScaleOut"
  })
}

# --- Scale-In Alarm --- #
# Removes an instance from the ASG when CPU utilization falls below the threshold.
# Important: Ensure this alarm is properly tested to avoid premature scale-in during temporary load drops.
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  count = var.enable_scale_in_alarm ? 1 : 0 # Enabled only if scale-in alarm is allowed

  alarm_name          = "${var.name_prefix}-scale-in-${var.environment}"
  alarm_description   = "Triggers when CPU utilization falls below ${var.scale_in_cpu_threshold}% for 5 minutes, causing an instance to be removed from the ASG."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.enable_scaling_policies ? [aws_autoscaling_policy.scale_in_policy[0].arn] : [] # Trigger the scale-in policy
  ok_actions          = [var.sns_topic_arn]                                                                # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-scale-in-${var.environment}"
    Type      = "CPU"
    AlertType = "ASG:ScaleIn"
  })
}

# --- ASG Instance Health Alarm --- #
# Monitors instance-level health failures detected by EC2 status checks (hardware/network/OS issues).
# Complements ALB health checks and provides deeper infrastructure-level visibility.
resource "aws_cloudwatch_metric_alarm" "asg_status_check_failed" {
  count = var.enable_asg_status_check_alarm ? 1 : 0 # Enabled only if ASG status check alarm is allowed

  alarm_name          = "${var.name_prefix}-asg-status-check-failed-${var.environment}"
  alarm_description   = "Triggers when an instance in the ASG fails its status checks for 5 minutes, indicating a potential issue with the instance's health."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn] # Notify via SNS topic
  ok_actions          = [var.sns_topic_arn] # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-asg-status-check-failed-${var.environment}"
    Type      = "Health"
    AlertType = "ASG:InstanceStatusCheck"
  })
}

# --- High Incoming Network Traffic Alarm --- #
# Monitors abnormal inbound traffic spikes. 
# Recommended: Enable in production to detect potential DDoS or scraping attacks early.
resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  count = var.enable_high_network_in_alarm ? 1 : 0 # Enabled only if high network-in alarm is allowed

  alarm_name          = "${var.name_prefix}-high-network-in-${var.environment}"
  alarm_description   = "Triggers when incoming network traffic exceeds ${var.network_in_threshold} bytes over a 5-minute period, potentially indicating a DDoS attack or unexpected traffic spike."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2 # The number of datapoints that must be breaching to trigger the alarm.
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_in_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn] # Notify via SNS topic
  ok_actions          = [var.sns_topic_arn] # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-high-network-in-${var.environment}"
    Type      = "NetworkIn"
    AlertType = "ASG:NetworkIn"
  })
}

# --- High Outgoing Network Traffic Alarm --- #
# Monitors unusual outbound traffic spikes.
# Recommended: Enable in production to detect potential data leaks or compromised instances.
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  count = var.enable_high_network_out_alarm ? 1 : 0 # Enabled only if high network-out alarm is allowed

  alarm_name          = "${var.name_prefix}-high-network-out-${var.environment}"
  alarm_description   = "Triggers when outgoing network traffic exceeds ${var.network_out_threshold} bytes over a 5-minute period, potentially indicating data exfiltration or excessive outbound traffic."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2 # The number of datapoints that must be breaching to trigger the alarm.
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.network_out_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn] # Notify via SNS topic
  ok_actions          = [var.sns_topic_arn] # Notify via SNS when the alarm state returns to OK to confirm system stability.
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-high-network-out-${var.environment}"
    Type      = "NetworkOut"
    AlertType = "ASG:NetworkOut"
  })
}

# --- Notes --- #
# 1. **Alarm Logic**:
#    - Each alarm is controlled by individual boolean variables (e.g., `enable_scale_out_alarm`, `enable_high_network_in_alarm`).
#    - All alarms use `treat_missing_data = "notBreaching"` to minimize false positives if no data is reported.
#
# 2. **Scaling Alarms (Simple Policies Only)**:
#    - `scale_out_alarm`: Triggers the `scale_out_policy` when average CPU utilization exceeds the specified threshold.
#    - `scale_in_alarm`: Triggers the `scale_in_policy` when average CPU utilization drops below the specified threshold.
#    - Both alarms depend on `enable_scaling_policies = true` and require explicit connection to simple scaling policies.
#    - Designed for environments where manual scaling control via CloudWatch Alarms is required.
#    - **Note:** These alarms are not connected to `target_tracking_scaling_policy` — Target Tracking creates its own internal alarms automatically.
#
# 3. **Health Monitoring**:
#    - `asg_status_check_failed`: Monitors EC2 instance health at the system level using AWS status checks.
#    - Complements ALB health checks by detecting low-level instance issues (e.g., hardware failure, OS issues).
#    - Can be enabled for deeper system visibility.
#
# 4. **Traffic Monitoring**:
#    - `high_network_in`: Detects unusually high incoming network traffic, which may indicate potential DDoS attacks or traffic spikes.
#    - `high_network_out`: Detects unusually high outgoing network traffic, which may indicate data exfiltration or unexpected outbound spikes.
#    - Both alarms use 3 evaluation periods and require 2 breaching datapoints for reliability and reduced false positives.
#
# 5. **SNS Notifications**:
#    - All alarms send notifications to the configured SNS topic (`sns_topic_arn`) on both ALARM and OK state transitions.
#    - Ensures real-time alerting and recovery visibility.
#
# 6. **Scalability and Flexibility**:
#    - The modular design allows for easy addition or removal of specific alarms based on environment or project requirements.
#    - Each alarm is independently controlled, making it suitable for fine-tuning per environment (dev, stage, prod).
#
# 7. **Production Best Practices**:
#    - Enable `scale_out_alarm` and `scale_in_alarm` for predictable scaling.
#    - Always enable `high_network_in` and `high_network_out` alarms in production for traffic anomaly detection.
#    - Monitor alarm triggering patterns and adjust thresholds to match expected load profiles.
#    - Use `treat_missing_data = "notBreaching"` carefully — for critical alarms, consider `missing` handling strategy review.
#    - For critical metrics (e.g., instance status checks), consider using `treat_missing_data = "breaching"` instead of `notBreaching` to catch silent failures.