# --- EC2 Auto Scaling Group Configuration --- #

# Define the Auto Scaling Group with desired number of instances and subnet allocation.
resource "aws_autoscaling_group" "ec2_asg" {
  # Desired, minimum, and maximum instance counts
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

  # --- Lifecycle Configuration --- #
  # Ensure new instances are created before destroying old ones
  lifecycle {
    create_before_destroy = true
  }

  # --- Dependencies --- #
  # Ensure ASG depends on the latest Launch Template
  depends_on = [aws_launch_template.ec2_launch_template]

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

# --- Target Tracking Scaling Policy --- #

# Define a target tracking scaling policy for the Auto Scaling Group.
resource "aws_autoscaling_policy" "target_tracking_scaling_policy" {
  name                   = "${var.name_prefix}-target-tracking-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name

  target_tracking_configuration {
    target_value = 50 # Target CPU utilization percentage
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# --- Data Source to Fetch EC2 Instance IDs --- #

# Fetch instances launched by the Auto Scaling Group
data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.ec2_asg.name]
  }
}