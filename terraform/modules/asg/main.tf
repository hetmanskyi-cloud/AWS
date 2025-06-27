# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# --- ASG Auto Scaling Group Configuration --- #
# Configures the Auto Scaling Group (ASG) to dynamically adjust instance capacity based on traffic and application load.

# Define the Auto Scaling Group with desired number of instances and subnet allocation.
resource "aws_autoscaling_group" "asg" {

  name = "${var.name_prefix}-asg-${var.environment}" # Name of the Auto Scaling Group

  # Desired, minimum, and maximum instance counts
  min_size         = var.autoscaling_min  # Minimum number of instances
  max_size         = var.autoscaling_max  # Maximum number of instances
  desired_capacity = var.desired_capacity # Number of instances to maintain; null enables dynamic adjustment by ASG

  vpc_zone_identifier = var.public_subnet_ids # Subnets for ASG instances

  # Associates the ASG with the defined Launch Template that specifies instance configurations in asg/launch_template.tf
  launch_template {
    id      = aws_launch_template.asg_launch_template.id
    version = aws_launch_template.asg_launch_template.latest_version

    # Note: Using latest_version (instead of "$Latest") ensures that Terraform tracks Launch Template version changes.
    # This enables automatic instance_refresh (rolling update) when the template is updated.
    #
    # This approach is safer and more predictable than using "$Latest", especially in production.
    # It allows Terraform to detect version changes and refresh ASG instances accordingly.
    #
    # For mission-critical environments, pinning to a specific version (e.g., "3") is an option to prevent unintended rollouts.
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
      Name = "${var.name_prefix}-asg-instance-${var.environment}" # One template name for all ASG instances
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Enable instance refresh to ensure rolling updates when the Launch Template changes
  # This ensures that instances are replaced with the latest configuration without downtime.
  instance_refresh {
    strategy = "Rolling" # Use rolling updates to replace instances gradually
    preferences {
      min_healthy_percentage = 90  # Maintain at least 90% of instances healthy during refresh
      instance_warmup        = 300 # Wait for 5 minutes before considering new instances healthy
    }
  }

  # Enable instance monitoring for detailed metrics
  # This allows for better visibility into instance performance and health.
  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances"]
}

# --- Auto Scaling Policies --- #
# Defines scaling rules that dynamically adjust instance count based on defined thresholds for CPU utilization.

# Scale-out policy to add an instance when CPU utilization is high
resource "aws_autoscaling_policy" "scale_out_policy" {
  count = var.enable_scaling_policies ? 1 : 0 # Enable only if scaling policies are allowed

  name                   = "${var.name_prefix}-scale-out-policy-${var.environment}"
  scaling_adjustment     = 1 # Add one instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period (in seconds) between scaling actions. Aligned with health_check_grace_period.
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Scale-in policy to remove an instance when CPU utilization is low
resource "aws_autoscaling_policy" "scale_in_policy" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.name_prefix}-scale-in-policy-${var.environment}"
  scaling_adjustment     = -1 # Remove one instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period (in seconds) between scaling actions. Aligned with health_check_grace_period.
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# --- Target Tracking Scaling Policy --- #

# Define a target tracking scaling policy for the Auto Scaling Group.
resource "aws_autoscaling_policy" "target_tracking_scaling_policy" {
  count = var.enable_target_tracking ? 1 : 0

  name                   = "${var.name_prefix}-target-tracking-scaling-policy-${var.environment}"
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
# Optional: Enabled only if enable_data_source = true
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

# 2. **Target Group Integration**:
#    - ASG instances are attached to the ALB's Target Group (wordpress_tg_arn) for traffic routing and health monitoring.

# 3. **Health Checks**:
#    - The ASG uses ELB (ALB) health checks to ensure instance availability and application-level responsiveness.

# 4. **Scaling Policies Control**:
#    - **Simple scaling policies** (scale_out_policy, scale_in_policy) are controlled via the `enable_scaling_policies` variable.
#      - scale_out_policy: Adds an instance when CPU utilization exceeds the defined threshold.
#      - scale_in_policy: Removes an instance when CPU utilization drops below the defined threshold.
#      - These rely on manually defined CloudWatch Alarms for triggering.

#    - **Target Tracking Scaling Policy** is controlled separately via the `enable_target_tracking` variable.
#      - Automatically adjusts ASG capacity to maintain the target average CPU utilization (default: 50%).
#      - AWS manages CloudWatch Alarms internally (no manual alarm configuration needed).
#      - When CloudWatch Logs are enabled, each instance can publish logs (user data, Nginx, etc.) to dedicated log groups.

# 5. **Data Source**:
#    - The optional `aws_instances` data source retrieves instance IDs dynamically from the ASG.
#    - Useful for monitoring dashboards, scripts, or integrations.
#    - Controlled via the `enable_data_source` variable to avoid unnecessary overhead when unused.

# 6. **Launch Template Handling and Rolling Updates**:
#    - The ASG uses a Launch Template for instance configuration, with `version = aws_launch_template.latest_version`.
#    - This ensures Terraform detects version changes and triggers `instance_refresh` automatically.
#    - Safer and more predictable than using the raw string "$Latest", which bypasses Terraform’s change detection.
#    - The `instance_refresh` block ensures rolling replacement of EC2 instances when the Launch Template changes.
#      - This guarantees zero downtime and avoids the need for manual instance termination.
#    - The `lifecycle { create_before_destroy = true }` block further ensures that updates happen without disruption.

# 7. **Security and Best Practices**:
#    - Always use IAM roles with least privilege.
#    - Monitor scaling behavior during load tests to validate auto scaling policy responses.
#    - Avoid using `"$Latest"` for Launch Templates in production to prevent untracked updates.
#    - Prefer `latest_version` (tracked by Terraform) for safe and visible rollouts in dev/staging environments.
#    - Use Terraform outputs and monitoring to observe instance refreshes and scaling actions.
#    - Ensure that the `health_check_grace_period` aligns with application startup times to avoid premature health checks.
