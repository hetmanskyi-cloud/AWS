# --- EC2 Launch Template Configuration --- #
# This configuration sets up an EC2 Launch Template for use with an Auto Scaling Group.
# It defines instance specifications, storage, security settings, metadata options, and monitoring.

resource "aws_launch_template" "ec2_launch_template" {
  # Template name prefix
  name_prefix = "${var.name_prefix}-ec2-launch-template"
  description = "Launch template for EC2 instances with auto-scaling configuration"

  # --- Instance Specifications --- #
  # Define the AMI ID and instance type. Variables are used for flexible configuration.
  image_id      = var.ami_id        # Dynamic AMI ID for Ubuntu in specified region
  instance_type = var.instance_type # Instance type for AWS Free Tier
  key_name      = var.ssh_key_name  # SSH key name for accessing instances

  # --- Block Device Mappings --- #
  # Configure the root EBS volume: 8 GiB, encryption enabled.
  block_device_mappings {
    device_name = "/dev/xvda" # Default root device for Ubuntu AMIs
    ebs {
      volume_size           = var.volume_size # Volume size in GiB
      volume_type           = var.volume_type # General Purpose SSD (gp2 or gp3)
      encrypted             = true            # Enable encryption for root EBS volume
      delete_on_termination = true            # Delete the volume when instance terminates
    }
  }

  # --- Security and Metadata Settings --- #
  # Disable termination protection and enable instance metadata access.
  disable_api_termination              = false
  instance_initiated_shutdown_behavior = "terminate" # Terminate instance on shutdown
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata endpoint
    http_tokens                 = "required" # Require tokens (IMDSv2)
    http_put_response_hop_limit = 2          # Limit metadata access to 2 hops
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags
  }

  # --- Monitoring and EBS Optimization --- #
  # Enable detailed monitoring and EBS optimization for improved performance.
  monitoring {
    enabled = true # Enable detailed monitoring
  }
  ebs_optimized = true # EBS-optimized instance for higher I/O

  # --- IAM Instance Profile --- #
  # Attach an IAM instance profile for access management.
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name # Use IAM instance profile defined in ec2/iam.tf
  }

  # --- Network Interface Configuration --- #
  # Automatically assign a public IP and delete the network interface on termination.
  # Security groups are now set via vpc_security_group_ids for compatibility.
  network_interfaces {
    associate_public_ip_address = true                  # Associate public IP
    delete_on_termination       = true                  # Delete interface upon instance termination
    security_groups             = var.security_group_id # Security groups for access control
  }

  # --- Tag Specifications --- #
  # Apply tags to all instances created with this launch template.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name_prefix}-ec2-instance"
      Environment = var.environment
    }
  }

  # --- User Data --- #
  # Specify a user_data script for initial instance configuration.
  user_data = var.user_data # Initial setup script for the instance
}
