# --- EC2 Outputs --- #

# Output the ID of the Auto Scaling Group
# Useful for referencing the Auto Scaling Group in other modules or debugging scaling-related issues.
# The explicit `depends_on` ensures that the ASG is fully created before its ID is referenced in other modules.
# While Terraform implicitly manages dependencies, this addition improves clarity for the team.
output "ec2_asg_id" {
  description = "The ID of the EC2 Auto Scaling Group"
  value       = var.environment != "dev" ? aws_autoscaling_group.ec2_asg[0].id : null
  depends_on  = [aws_autoscaling_group.ec2_asg]
}

# Output the latest version of the Launch Template
# Provides the latest version number of the EC2 Launch Template, ensuring the most up-to-date configuration.
output "launch_template_latest_version" {
  description = "The latest version of the EC2 Launch Template"
  value       = aws_launch_template.ec2_launch_template.latest_version
}

# Output the Launch Template ID
# Useful for referencing the Launch Template when creating or debugging Auto Scaling Groups.
output "launch_template_id" {
  description = "The ID of the EC2 Launch Template"
  value       = aws_launch_template.ec2_launch_template.id
}

# Output the Public IPs of instances (if assigned)
# Provides the public IP addresses of instances, useful for debugging or temporary access in dev environments.
output "instance_public_ips" {
  description = "Public IPs of instances in the Auto Scaling Group (if assigned)"
  value       = var.environment != "dev" ? data.aws_instances.asg_instances[0].public_ips : null
}

# Output the Private IPs of instances
# Useful for internal communication between instances or debugging private network configurations.
output "instance_private_ips" {
  description = "Private IPs of instances in the Auto Scaling Group"
  value       = var.environment != "dev" ? data.aws_instances.asg_instances[0].private_ips : null
}

# Output the Instance IDs of instances in the Auto Scaling Group
# Provides a list of instance IDs for monitoring, debugging, or further automation workflows.
output "instance_ids" {
  description = "Instance IDs of instances in the Auto Scaling Group"
  value       = var.environment != "dev" ? data.aws_instances.asg_instances[0].ids : null
}

# --- Security Group Output --- #

# Output the Security Group ID used for the EC2 instances
# Ensures the Security Group for EC2 instances can be referenced in other modules or debugging network configurations.
output "ec2_security_group_id" {
  description = "ID of the Security Group created for EC2 instances"
  value       = aws_security_group.ec2_security_group.id
}

# --- Scaling Policy Outputs --- #

# Output the ARN of the Scale-Out Policy
# Provides the ARN of the scaling policy for increasing instance count based on utilization.
output "scale_out_policy_arn" {
  description = "ARN of the Scale-Out Policy"
  value       = var.environment != "dev" ? aws_autoscaling_policy.scale_out_policy[0].arn : null
}

# Output the ARN of the Scale-In Policy
# Provides the ARN of the scaling policy for decreasing instance count based on utilization.
output "scale_in_policy_arn" {
  description = "ARN of the Scale-In Policy"
  value       = var.environment != "dev" ? aws_autoscaling_policy.scale_in_policy[0].arn : null
}

# --- Additional Outputs --- #

# Output for SSM Managed Instance IDs
output "ssm_managed_instance_ids" {
  description = "IDs of EC2 instances managed via SSM"
  value       = var.environment != "dev" ? data.aws_instances.asg_instances[0].ids : null
}

# --- Output Notes --- #
# 1. **ASG Outputs**:
#    - Outputs related to Auto Scaling Group (ASG), such as `ec2_asg_id`, are disabled in `dev` where ASG is not created.
#
# 2. **Security Group Output**:
#    - The `ec2_security_group_id` is available across all environments for referencing in other modules.
#
# 3. **Scaling Policies**:
#    - The ARNs of scaling policies (`scale_out_policy_arn`, `scale_in_policy_arn`) are provided for integration with monitoring and scaling workflows.
#
# 4. **SSM Integration**:
#    - The `ssm_managed_instance_ids` output simplifies integration with operational tools that rely on SSM for instance management.
#
# 5. **Environment Logic**:
#    - Outputs dynamically adjust based on the environment to ensure irrelevant data is excluded in `dev`.
#    - `instance_public_ips` and `instance_private_ips` are particularly useful for debugging network configurations or testing in dev environments.
#
# 6. **Best Practices**:
#    - Use `instance_public_ips` and `instance_private_ips` cautiously in production to maintain secure configurations.
#    - Regularly review scaling thresholds and policies to optimize resource usage in `stage` and `prod`.