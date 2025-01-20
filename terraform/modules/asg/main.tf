# --- ASG Auto Scaling Group Configuration --- #
# Configures the Auto Scaling Group (ASG) to dynamically adjust instance capacity based on traffic and application load.

# Define the Auto Scaling Group with desired number of instances and subnet allocation.
resource "aws_autoscaling_group" "asg" {

  # Desired, minimum, and maximum instance counts
  min_size         = var.autoscaling_min  # Minimum number of instances
  max_size         = var.autoscaling_max  # Maximum number of instances
  desired_capacity = var.desired_capacity # Number of instances to maintain; null enables dynamic adjustment by ASG

  vpc_zone_identifier = var.public_subnet_ids # Subnets for ASG instances

  # Associates the ASG with the defined Launch Template that specifies instance configurations in asg/launch_template.tf
  launch_template {
    id      = aws_launch_template.asg_launch_template.id
    version = "$Latest" # Use the latest version of the launch template

    # Warning: Using "$Latest" for versioning may lead to unintended updates in production.
    # Consider specifying an explicit version for better control, especially in production environments.
    # Alternatively, ensure lifecycle { create_before_destroy = true } is set to avoid downtime.
  }

  # Health check configuration
  health_check_type         = "ELB" # ALB health checks are used to ensure application-level availability of instances
  health_check_grace_period = 300   # Grace period (seconds) for instances to warm up

  # Attach Target Group for ALB
  target_group_arns = length(var.wordpress_tg_arn) > 0 ? [var.wordpress_tg_arn] : [] # List of Target Group ARNs to route traffic from ALB to ASG instances

  # Scaling policies for ASG
  wait_for_capacity_timeout = "0" # Skip capacity waiting and allow ASG to provision instances without delays.

  # Termination policy for balanced scaling
  # Terminate the oldest instance first to ensure stability and cost-effectiveness.
  # If an immediate replacement is required, the newest instance will be terminated first.
  termination_policies = ["OldestInstance", "NewestInstance"]

  # --- Lifecycle Configuration --- #
  # Ensures rolling updates by creating new instances before terminating old ones, avoiding downtime
  lifecycle {
    create_before_destroy = true
  }

  # --- Dependencies --- #
  # Ensure ASG depends on the latest Launch Template
  # This guarantees that the Auto Scaling Group always uses the most up-to-date configuration.
  depends_on = [aws_launch_template.asg_launch_template]

  # Tags applied to all instances launched in the Auto Scaling Group
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# --- Auto Scaling Policies --- #
# Defines scaling rules that dynamically adjust instance count based on defined thresholds for CPU utilization.

# Scale-out policy to add an instance when CPU utilization is high
resource "aws_autoscaling_policy" "scale_out_policy" {
  count = var.enable_scaling_policies ? 1 : 0 # Enable only if scaling policies are allowed

  name                   = "${var.name_prefix}-scale-out-policy"
  scaling_adjustment     = 1 # Add one instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period (in seconds) between scaling actions. Aligned with health_check_grace_period.
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Scale-in policy to remove an instance when CPU utilization is low
resource "aws_autoscaling_policy" "scale_in_policy" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.name_prefix}-scale-in-policy"
  scaling_adjustment     = -1 # Remove one instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period (in seconds) between scaling actions. Aligned with health_check_grace_period.
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# --- Target Tracking Scaling Policy --- #

# Define a target tracking scaling policy for the Auto Scaling Group.
resource "aws_autoscaling_policy" "target_tracking_scaling_policy" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.name_prefix}-target-tracking-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 50 # Target CPU utilization percentage
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# --- Data Source to Fetch ASG Instance IDs --- #
# Retrieves instance IDs dynamically to facilitate monitoring and management through AWS data sources.
data "aws_instances" "asg_instances" {
  count = var.enable_data_source ? 1 : 0 # Enable only if data source is required

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.asg.name]
  }
}

# --- Notes --- #
# 1. **ASG Logic**:
#    - Optional scaling policies (`scale_out_policy`, `scale_in_policy`, `target_tracking_scaling_policy`) are enabled via the `enable_scaling_policies` variable.
#
# 2. **Target Group Integration**:
#    - The ASG instances are attached to the ALB's Target Group (`wordpress_tg_arn`).
#
# 3. **Health Checks**:
#    - The ASG uses ELB (ALB) health checks to ensure instance availability.
#
# 4. **Scaling Policies**:
#   - `scale_out_policy`: Triggers a scale-out action (adds an instance) when CPU utilization exceeds the target.
#   - `scale_in_policy`: Triggers a scale-in action (removes an instance) when CPU utilization drops below the target.
#   - `target_tracking_scaling_policy`: Automatically adjusts capacity to maintain a target CPU utilization percentage (default: 50%).
#
# 5. **Data Source**:
#   - Dynamically retrieves ASG instance details for monitoring or further integrations.
#   - Controlled by the `enable_data_source` variable to optimize resource usage in environments where this data is not needed.
#
# 6. **Dependencies**:
#    - The ASG relies on a Launch Template and Target Group for configuration.