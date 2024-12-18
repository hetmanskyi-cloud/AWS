# --- EC2 Launch Template Configuration --- #

# Parse the AMI ID directly from the S3 object using JSON decoding
data "aws_s3_object" "latest_ami" {
  bucket = var.ami_bucket_name # Name of the S3 bucket containing AMI metadata
  key    = "latest-ami.json"   # Key of the file storing the latest AMI ID
}

# Launch Template for Auto Scaling Group. Instances are created using the latest AMI stored in S3.
# Defines instance specifications, storage, security settings, metadata options, monitoring, and tags. 
resource "aws_launch_template" "ec2_launch_template" {
  # --- Template Settings --- #
  # The name_prefix ensures unique naming for launch templates.
  name_prefix = "${var.name_prefix}-ec2-launch-template"
  description = "Launch template for EC2 instances with auto-scaling configuration"

  # --- Lifecycle Management --- #
  # Ensure a new launch template is created before the old one is destroyed during updates.
  lifecycle {
    create_before_destroy = true # Ensure no downtime during template updates
  }

  # --- Instance Specifications --- #
  # Define the AMI ID dynamically fetched from S3 and the instance type.
  image_id      = jsondecode(data.aws_s3_object.latest_ami.body).ami_id # Parse AMI ID from S3 object
  instance_type = var.instance_type                                     # Instance type (e.g., t2.micro for AWS Free Tier)

  # --- Block Device Mappings --- #
  # Configure the root EBS volume with encryption enabled.
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume device name for image AMIs
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
  # Deny public IPs and set security groups for instance networking.
  network_interfaces {
    associate_public_ip_address = false                                      # Disable public IPs
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
  # In stage/prod, the instances use the AMI prepared in dev. No additional user_data is applied.
  user_data = null
}

# --- Notes --- #
# 1. AMI ID is dynamically fetched from the S3 bucket containing the latest AMI metadata.
# 2. Public IPs are disabled for all ASG instances in stage/prod environments.
# 3. Instances in stage/prod use the AMI prepared in dev, stored in S3.
# 4. User data is not required for stage/prod, as the golden AMI includes all configurations.
# 5. Security Group rules are strictly controlled for prod to minimize attack surface.
# 6. Monitoring and EBS optimization are enabled for better performance and visibility.
# 7. IMDSv2 is enforced for enhanced security of instance metadata.
# 8. SSH access is disabled; access and management are conducted exclusively through AWS Systems Manager (SSM).
# 9. Updates to the AMI in the S3 metadata file are automatically reflected in the Auto Scaling Group after the Launch Template is updated.
# 10. To ensure seamless updates, use an EventBridge rule or manual process to update the S3 metadata file with the latest AMI.