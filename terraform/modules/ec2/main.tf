# --- EC2 Auto Scaling Group Configuration --- #

# Define the Auto Scaling Group with desired number of instances and subnet allocation
resource "aws_autoscaling_group" "ec2_asg" {
  desired_capacity    = var.autoscaling_desired                                                  # Desired number of instances
  min_size            = var.autoscaling_min                                                      # Minimum number of instances
  max_size            = var.autoscaling_max                                                      # Maximum number of instances
  vpc_zone_identifier = [var.public_subnet_id_1, var.public_subnet_id_2, var.public_subnet_id_3] # Subnets for EC2 instances

  # Reference the launch template created in launch_template.tf
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest" # Use the latest version of the launch template
  }

  # Health check configuration
  health_check_type         = "EC2" # Health check based on EC2 instance status
  health_check_grace_period = 300   # Grace period for new instances to warm up

  # Scaling policies for ASG
  wait_for_capacity_timeout = "0" # Disable waiting for instances to become healthy

  # Termination policy for balanced scaling
  termination_policies = ["OldestInstance"]

  # Tags applied to all instances launched in the Auto Scaling Group
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ec2-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

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
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn]
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
  alarm_actions       = [aws_autoscaling_policy.scale_in_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }
}

# --- Auto Scaling Policies --- #
# Define scaling policies to automatically adjust capacity based on load.

# Scale-out policy to add an instance when CPU utilization is high
resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "${var.name_prefix}-scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name
}

# Scale-in policy to remove an instance when CPU utilization is low
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "${var.name_prefix}-scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name
}