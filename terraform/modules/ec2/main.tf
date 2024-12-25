# --- EC2 Auto Scaling Group Configuration --- #
# Auto Scaling Group is created only in stage and prod environments.
# For dev, only a single instance (managed in instance_image.tf) is created.

# Define the Auto Scaling Group with desired number of instances and subnet allocation.
resource "aws_autoscaling_group" "ec2_asg" {
  count = var.environment != "dev" ? 1 : 0 # ASG is disabled in dev

  # Desired, minimum, and maximum instance counts
  min_size            = var.autoscaling_min   # Minimum number of instances
  max_size            = var.autoscaling_max   # Maximum number of instances
  desired_capacity    = null                  # Let ASG dynamically adjust capacity in stage/prod
  vpc_zone_identifier = var.public_subnet_ids # Subnets for EC2 instances

  # Reference the launch template created in launch_template.tf
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest" # Use the latest version of the launch template
  }

  # Health check configuration
  health_check_type         = "ELB" # Health check based on ALB health checks
  health_check_grace_period = 300   # Grace period for new instances to warm up

  # Attach Target Group for ALB
  target_group_arns = var.environment != "dev" ? [var.target_group_arn] : [] # ARN of the Target Group from ALB module

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
  count                  = var.environment != "dev" ? 1 : 0 # Scale-out is disabled in dev
  name                   = "${var.name_prefix}-scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ec2_asg[0].name
}

# Scale-in policy to remove an instance when CPU utilization is low
resource "aws_autoscaling_policy" "scale_in_policy" {
  count                  = var.environment != "dev" ? 1 : 0 # Scale-in is disabled in dev
  name                   = "${var.name_prefix}-scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ec2_asg[0].name
}

# --- Target Tracking Scaling Policy --- #

# Define a target tracking scaling policy for the Auto Scaling Group.
resource "aws_autoscaling_policy" "target_tracking_scaling_policy" {
  count                  = var.environment != "dev" ? 1 : 0 # Target tracking is disabled in dev
  name                   = "${var.name_prefix}-target-tracking-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.ec2_asg[0].name

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
  count = var.environment != "dev" ? 1 : 0 # Data source is disabled in dev

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.ec2_asg[0].name]
  }
}

# --- Notes --- #
# 1. **ASG Environment Logic**:
#    - In `dev`: Auto Scaling Group (ASG) is disabled. Only `instance_image` is managed.
#    - In `stage` and `prod`: ASG is fully enabled for automated scaling based on load and health checks.
#
# 2. **Scaling Policies**:
#    - Scale-out and scale-in policies are applied to dynamically adjust capacity based on CPU utilization.
#
# 3. **Health Checks**:
#    - Health checks are integrated with ALB (`ELB` type) to ensure instances are healthy and responsive.
#
# 4. **Dynamic Configuration**:
#    - The use of `count` enables resource creation only in relevant environments.
#
# 5. **Dependencies**:
#    - Target Group ARN (`target_group_arns`) connects ASG to ALB for traffic routing and monitoring.
#    - Launch Template ensures consistent instance configurations across environments.