# --- EC2 Launch Template Configuration --- #
# This configuration sets up a detailed EC2 Launch Template for use with an Auto Scaling Group.
# The template includes specifications for instance type, block storage, security settings, and metadata options.

resource "aws_launch_template" "ec2_launch_template" {
  name_prefix = "${var.name_prefix}-ec2-launch-template"
  description = "Launch template for EC2 instances with auto-scaling configuration"

  # --- Instance Specifications --- #
  # Define the AMI and instance type. In this example, we use Ubuntu with t2.micro for development purposes.
  image_id      = var.ami_id        # Dynamic AMI ID for Ubuntu in specified region
  instance_type = var.instance_type # Instance type for AWS Free Tier
  key_name      = var.ssh_key_name  # Name of the SSH key for accessing instances

  # --- Block Device Mappings --- #
  # Configure the root EBS volume with a size of 8 GiB and encryption enabled.
  block_device_mappings {
    device_name = "/dev/xvda" # Default root device for Ubuntu AMIs
    ebs {
      volume_size           = var.volume_size # Set volume size in GiB
      volume_type           = var.volume_type # General Purpose SSD
      encrypted             = true            # Enable encryption for the root EBS volume
      delete_on_termination = true            # Automatically delete the volume upon instance termination
    }
  }

  # --- Security and Metadata Settings --- #
  # Disable termination protection, enable instance metadata access, and restrict metadata access tokens.
  disable_api_termination              = false
  instance_initiated_shutdown_behavior = "terminate" # Instance terminates on shutdown
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata endpoint
    http_tokens                 = "required" # Enforce IMDSv2 (metadata token required)
    http_put_response_hop_limit = 2          # Restrict metadata response to within 2 hops
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags
  }

  # --- Monitoring and EBS Optimization --- #
  # Enable detailed monitoring and EBS optimization for improved performance.
  monitoring {
    enabled = true
  }
  ebs_optimized = true # EBS-optimized instance for increased I/O

  # --- IAM Instance Profile --- #
  # Associate the EC2 instance with an IAM role if needed.
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name # Use the IAM instance profile defined in ec2/iam.tf
  }

  # --- Network Interface Configuration --- #
  # Associate a public IP address and specify Security Group IDs for network interfaces.
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = var.security_group_id # Define Security Group ID for access control
  }

  # --- Tag Specifications --- #
  # Apply tags to all instances created using this launch template.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name_prefix}-ec2-instance"
      Environment = var.environment
    }
  }

  # --- User Data --- #
  # Specify a user_data script for initial instance configuration (e.g., install software).
  user_data = var.user_data # User data script
}