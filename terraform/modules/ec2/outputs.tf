# --- EC2 Outputs --- #

# Output the ID of the Auto Scaling Group
# Useful for referencing the Auto Scaling Group in other modules or debugging scaling-related issues.
output "ec2_asg_id" {
  description = "The ID of the EC2 Auto Scaling Group"
  value       = aws_autoscaling_group.ec2_asg.id
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
  value       = data.aws_instances.asg_instances.public_ips
}

# Output the Private IPs of instances
# Useful for internal communication between instances or debugging private network configurations.
output "instance_private_ips" {
  description = "Private IPs of instances in the Auto Scaling Group"
  value       = data.aws_instances.asg_instances.private_ips
}

# Output the Instance IDs of instances in the Auto Scaling Group
# Provides a list of instance IDs for monitoring, debugging, or further automation workflows.
output "instance_ids" {
  description = "Instance IDs of instances in the Auto Scaling Group"
  value       = data.aws_instances.asg_instances.ids
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
  value       = aws_autoscaling_policy.scale_out_policy.arn
}

# Output the ARN of the Scale-In Policy
# Provides the ARN of the scaling policy for decreasing instance count based on utilization.
output "scale_in_policy_arn" {
  description = "ARN of the Scale-In Policy"
  value       = aws_autoscaling_policy.scale_in_policy.arn
}
