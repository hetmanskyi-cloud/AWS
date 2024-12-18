# --- EC2 Launch Template Configuration --- #
# This configuration sets up an EC2 Launch Template for use with an Auto Scaling Group.
# It defines instance specifications, storage, security settings, metadata options, monitoring, and tags.

resource "aws_launch_template" "ec2_launch_template" {
  # --- Template Settings --- #
  # The name_prefix ensures unique naming for launch templates.
  name_prefix = "${var.name_prefix}-ec2-launch-template"
  description = "Launch template for EC2 instances with auto-scaling configuration"

  # --- Lifecycle Management --- #
  # Ensure a new launch template is created before the old one is destroyed during updates.
  lifecycle {
    create_before_destroy = true
  }

  # --- Instance Specifications --- #
  # Define the AMI ID, instance type, and optional SSH key for access.
  image_id      = var.ami_id        # AMI ID for the desired operating system (e.g., Ubuntu)
  instance_type = var.instance_type # Instance type (e.g., t2.micro for AWS Free Tier)
  key_name      = var.ssh_key_name  # Optional SSH key name for instance access

  # --- Block Device Mappings --- #
  # Configure the root EBS volume with encryption enabled.
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume device name for Ubuntu AMIs
    ebs {
      volume_size           = var.volume_size # Volume size in GiB
      volume_type           = var.volume_type # Volume type (e.g., gp2, gp3)
      encrypted             = true            # Enable volume encryption
      delete_on_termination = true            # Automatically delete volume on instance termination
    }
  }

  # --- Security and Metadata Settings --- #
  # Enable instance metadata options and set termination behavior.
  disable_api_termination              = false       # Allow API termination
  instance_initiated_shutdown_behavior = "terminate" # Terminate instance on shutdown
  metadata_options {
    http_endpoint               = "enabled"  # Enable instance metadata endpoint
    http_tokens                 = "required" # Require IMDSv2 tokens
    http_put_response_hop_limit = 1          # Restrict metadata access to 1 hops
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags
  }

  # --- Monitoring and EBS Optimization --- #
  # Enable monitoring and optimization for higher performance.
  monitoring {
    enabled = true # Enable detailed CloudWatch monitoring
  }
  ebs_optimized = true # Enable EBS optimization for the instance

  # --- IAM Instance Profile --- #
  # Attach an IAM instance profile to manage permissions for the instance.
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name # IAM instance profile from ec2/iam.tf
  }

  # --- Network Interface Configuration --- #
  # Assign a public IP and set security groups for instance networking.
  network_interfaces {
    associate_public_ip_address = true                                       # Public IP is required for WordPress setup. Consider NAT Gateway in production.
    delete_on_termination       = true                                       # Delete interface on termination
    security_groups             = [aws_security_group.ec2_security_group.id] # Security groups for networking
  }

  # --- Tag Specifications --- #
  # Tags are applied to EC2 instances created with this Launch Template.
  # The tag `Name` is specific to instances and does not need to match the Launch Template resource name.
  tag_specifications {
    resource_type = "instance" # Apply tags to EC2 instances created with this template
    tags = {
      Name        = "${var.name_prefix}-ec2-instance" # Instance name tag
      Environment = var.environment                   # Environment tag (e.g., dev, stage, prod)
    }
  }

  # --- User Data --- #
  # Specify a user_data script for initial instance configuration.
  user_data = base64encode(templatefile("${path.root}/scripts/deploy_wordpress.sh", local.db_config))
}