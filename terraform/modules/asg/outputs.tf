# --- ASG Outputs --- #

# --- Auto Scaling Group Outputs --- #
# Provides key identifiers and attributes of the ASG for referencing in other modules.

# The ID of the Auto Scaling Group for referencing in other modules or debugging scaling issues.
output "asg_id" {
  description = "The ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.id
}

# The name of the Auto Scaling Group for tracking and referencing purposes.
output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.asg.name
}

# --- Instance Details --- #
# Outputs related to ASG instance monitoring and management.

# The instance IDs of ASG instances for monitoring, debugging, or automation workflows.
output "instance_ids" {
  description = "The instance IDs of instances in the Auto Scaling Group"
  value       = var.enable_data_source ? try(data.aws_instances.asg_instances[0].ids, []) : []
}

# The public IPs of ASG instances (if assigned), useful for debugging or temporary access.
output "instance_public_ips" {
  description = "The public IPs of instances in the Auto Scaling Group (if assigned)"
  value       = var.enable_data_source ? try(data.aws_instances.asg_instances[0].public_ips, []) : []
}

# The private IPs of ASG instances for internal communication or debugging.
output "instance_private_ips" {
  description = "The private IPs of instances in the Auto Scaling Group"
  value       = var.enable_data_source ? try(data.aws_instances.asg_instances[0].private_ips, []) : []
}

# --- Launch Template Details --- #

# Launch Template ID for reference when creating Auto Scaling Groups.
output "launch_template_id" {
  description = "The ID of the ASG Launch Template"
  value       = aws_launch_template.asg_launch_template.id
}

# Latest version of the Launch Template to ensure the most up-to-date configuration.
output "launch_template_latest_version" {
  description = "The latest version of the ASG Launch Template"
  value       = aws_launch_template.asg_launch_template.latest_version
}

# User_data
output "user_data" {
  description = "Encoded user data script"
  value       = aws_launch_template.asg_launch_template.user_data
  sensitive   = true
}

# --- Security Group Output --- #

# Security Group ID associated with ASG instances.
output "asg_security_group_id" {
  description = "ID of the Security Group created for ASG instances"
  value       = aws_security_group.asg_security_group.id
}

# --- Scaling Policy Outputs --- #

# ARN of the Scale-Out Policy to increase ASG capacity when utilization exceeds threshold.
output "scale_out_policy_arn" {
  description = "ARN of the Scale-Out Policy"
  value       = var.enable_scaling_policies ? try(aws_autoscaling_policy.scale_out_policy[0].arn, null) : null
}

# ARN of the Scale-In Policy to decrease ASG capacity when utilization drops below threshold.
output "scale_in_policy_arn" {
  description = "ARN of the Scale-In Policy"
  value       = var.enable_scaling_policies ? try(aws_autoscaling_policy.scale_in_policy[0].arn, null) : null
}

# --- Output Notes --- #
# 1. **ASG Outputs:**
#    - `asg_id` and `asg_name` provide core identifiers for the Auto Scaling Group.
#
# 2. **Instance Details:**
#    - Instance IDs, public IPs, and private IPs are available when `enable_data_source = true`.
#    - Instance IDs can be used for both general management and SSM operations.
#
# 3. **Launch Template:**
#    - `launch_template_id` and version help track instance configurations.
#
# 4. **Security Groups:**
#    - Security group ID enables additional rule management if needed.
#
# 5. **Scaling Policies:**
#    - Policy ARNs are exposed for CloudWatch Alarm integration.
#
# 6. **Best Practices:**
#    - Use private IPs for internal communication in production.
#    - Monitor scaling policy triggers through CloudWatch.
#    - Leverage SSM for secure instance management.