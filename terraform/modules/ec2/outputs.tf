# --- EC2 Outputs --- #

# Output the ID of the Auto Scaling Group
output "ec2_asg_id" {
  description = "The ID of the EC2 Auto Scaling Group"
  value       = aws_autoscaling_group.ec2_asg.id
}

# Output the latest version of the Launch Template
output "launch_template_latest_version" {
  description = "The latest version of the EC2 Launch Template"
  value       = aws_launch_template.ec2_launch_template.latest_version
}

# Output the Launch Template ID
output "launch_template_id" {
  description = "The ID of the EC2 Launch Template"
  value       = aws_launch_template.ec2_launch_template.id
}

# --- Instance Information Outputs via Data Source --- #
# Retrieves the public IPs, private IPs, and instance IDs using the aws_instances data source.

# Data source to gather all instances created by Auto Scaling Group using tag filtering
data "aws_instances" "ec2_instances" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-ec2-instance"]
  }
}

# Output the Public IPs of instances (if assigned)
output "instance_public_ips" {
  description = "Public IPs of instances in the Auto Scaling Group (if assigned)"
  value       = data.aws_instances.ec2_instances.public_ips
}

# Output the Private IPs of instances
output "instance_private_ips" {
  description = "Private IPs of instances in the Auto Scaling Group"
  value       = data.aws_instances.ec2_instances.private_ips
}

# Output the Instance IDs of instances in the Auto Scaling Group
output "instance_ids" {
  description = "Instance IDs of instances in the Auto Scaling Group"
  value       = data.aws_instances.ec2_instances.ids
}

# --- Security Group Output --- #

# Output the Security Group ID used for the EC2 instances
# This Security Group controls access to EC2 instances, allowing SSH, HTTP, and HTTPS traffic
output "ec2_security_group_id" {
  description = "ID of the Security Group created for EC2 instances"
  value       = aws_security_group.ec2_security_group.id
}

# --- Outputs for EC2 Instances --- #

# Output the public IP addresses of instances in the Auto Scaling Group
output "ec2_instance_public_ips" {
  description = "Public IP addresses of EC2 instances in the Auto Scaling Group"
  value       = data.aws_instances.asg_instances.public_ips
}

# Output the private IP addresses of instances in the Auto Scaling Group
output "ec2_instance_private_ips" {
  description = "Private IP addresses of EC2 instances in the Auto Scaling Group"
  value       = data.aws_instances.asg_instances.private_ips
}