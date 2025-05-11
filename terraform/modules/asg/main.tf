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
    id = aws_launch_template.asg_launch_template.id
    # CAUTION: "$Latest" always uses the latest version of the Launch Template.
    version = "$Latest" # Use the latest version of the launch template

    # Warning: Using "$Latest" for versioning may lead to unintended updates in production.
    # Recommended for dev/test. 
    # For production, use a specific version (e.g., "1") to prevent unintended updates causing downtime.
    # Alternatively, ensure lifecycle { create_before_destroy = true } is set to avoid downtime.
  }

  # Health check configuration
  # "ELB" type ensures the ASG uses the ALB's health check status.
  # This provides application-level monitoring (not just EC2 instance health).
  health_check_type         = "ELB" # Use ALB health checks for instance replacement decisions
  health_check_grace_period = 300   # Wait 5 minutes for instance warm-up before considering health status

  # Attach the ALB Target Group only if provided
  target_group_arns = length(var.wordpress_tg_arn) > 0 ? [var.wordpress_tg_arn] : [] # List of Target Group ARNs to route traffic from ALB to ASG instances

  # Scaling policies for ASG
  wait_for_capacity_timeout = "0" # Skip capacity waiting and allow ASG to provision instances without delays.

  # Termination policy for predictable scaling behavior
  # Terminate the oldest instance first to ensure stability and cost-effectiveness.
  # If an immediate replacement is required, the newest instance will be terminated first.
  termination_policies = ["OldestInstance", "NewestInstance"]

  # Lifecycle Configuration
  # Ensures rolling updates by creating new instances before terminating old ones, avoiding downtime
  lifecycle {
    create_before_destroy = true
  }

  # Dependencies
  # Ensure ASG depends on the latest Launch Template
  # This guarantees that the Auto Scaling Group always uses the most up-to-date configuration.
  depends_on = [aws_launch_template.asg_launch_template]

  # Tags applied to all instances launched in the Auto Scaling Group
  dynamic "tag" {
    for_each = merge(var.tags, {
      Name = "${var.name_prefix}-asg-instance"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
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
  count = var.enable_target_tracking ? 1 : 0

  name                   = "${var.name_prefix}-target-tracking-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  # Dynamically adjusts instance count to maintain average CPU utilization near the target value.
  # AWS automatically manages CloudWatch Alarms for this policy.
  target_tracking_configuration {
    target_value = 50 # Target CPU utilization percentage
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# --- Data Source to Fetch ASG Instance IDs --- #
# Retrieves instance IDs dynamically to facilitate monitoring and management through AWS data sources.
# Useful for:
# - Monitoring (e.g., dynamic dashboards)
# - Management tasks requiring instance IDs
# Optional: Enabled only if `enable_data_source = true`
data "aws_instances" "asg_instances" {
  count = var.enable_data_source ? 1 : 0 # Enable only if data source is required

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.asg.name]
  }
}

# --- Notes --- #
# 1. **ASG Logic**:
#    - The Auto Scaling Group (ASG) dynamically adjusts the number of EC2 instances based on scaling policies and health checks.
#
# 2. **Target Group Integration**:
#    - ASG instances are attached to the ALB's Target Group (`wordpress_tg_arn`) for traffic routing and health monitoring.
#
# 3. **Health Checks**:
#    - The ASG uses ELB (ALB) health checks to ensure instance availability and proper application-level monitoring.
#
# 4. **Scaling Policies Control**:
#    - **Simple scaling policies** (`scale_out_policy`, `scale_in_policy`) are controlled via the `enable_scaling_policies` variable.
#      - `scale_out_policy`: Adds an instance when CPU utilization exceeds the configured threshold.
#      - `scale_in_policy`: Removes an instance when CPU utilization drops below the configured threshold.
#      - These policies rely on external CloudWatch Alarms for triggering.
#
#    - **Target Tracking Scaling Policy** is controlled separately via the `enable_target_tracking` variable.
#      - `target_tracking_scaling_policy`: Automatically adjusts ASG capacity to maintain the target average CPU utilization (default: 50%).
#      - AWS manages the necessary CloudWatch Alarms internally for this policy (no external alarms required).
#      - When CloudWatch Logs are enabled, each instance also publishes custom logs (user data, nginx, etc.) to pre-created log groups.
#
# 5. **Data Source**:
#    - The optional `aws_instances` data source dynamically retrieves instance IDs from the ASG for monitoring or external integrations.
#    - Controlled by the `enable_data_source` variable to avoid unnecessary overhead when not required.
#
# 6. **Dependencies**:
#    - The ASG depends on the Launch Template and ALB Target Group.
#    - `lifecycle { create_before_destroy = true }` ensures zero downtime during updates or scaling events.
#    - If using "$Latest" for the Launch Template version, be aware that changes to the template will be picked up immediately by the ASG.
#    - This is acceptable for development, but for production environments, consider pinning to a specific version number for predictable behavior.
#
# 7. **Security and Best Practices**:
#    - Always review instance IAM roles to follow the principle of least privilege.
#    - Monitor scaling events to ensure scaling policies behave as expected.
#    - For production, avoid using "$Latest" for launch template versions.
#    - Consider instance refresh strategies or rolling updates for safer deployments.