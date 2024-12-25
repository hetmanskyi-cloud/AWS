# --- EC2 Launch Template Configuration --- #
# This configuration dynamically fetches the latest AMI from S3 and applies it to the Auto Scaling Group (ASG).
# It ensures instances use the pre-configured AMI with optional support for SSM and temporary SSH access.

# --- Fetch Latest AMI ID --- #
# Fetch the AMI ID dynamically from an S3 bucket containing AMI metadata.
data "aws_s3_object" "latest_ami" {
  bucket = var.ami_bucket_name # Name of the S3 bucket containing AMI metadata
  key    = "latest-ami.json"   # Key of the file storing the latest AMI ID
}

# --- EC2 Launch Template for ASG --- #
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
    http_tokens                 = "required" # Enforce IMDSv2 for metadata security
    http_put_response_hop_limit = 1          # Restrict metadata access to one hop
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
  # In stage/prod, the instances use the prepared AMI image. No additional user_data is applied.
  user_data = null
}

# --- Notes --- #
# 1. **Dynamic AMI Fetching**:
#    - AMI ID is fetched from S3 (`latest-ami.json`) to ensure the Auto Scaling Group always uses the latest image.
#    - Regular updates to the S3 file are required. Use EventBridge or manual processes for automation.
#    - **Important**: Always verify the validity of the `ami_bucket_name` variable and ensure the file exists in the bucket.
#
# 2. **Public IPs**:
#    - Public IPs are disabled for all ASG instances to enhance security.
#
# 3. **SSH Access**:
#    - SSH access is typically disabled for production environments.
#    - Temporary SSH access can be enabled for debugging or maintenance using the `enable_ssh_access` variable in `terraform.tfvars`.
#    - For better control, restrict SSH to specific IP ranges in prod via `ec2/security_group.tf`.
#
# 4. **SSM Management**:
#    - All instances are fully manageable via AWS Systems Manager (SSM), eliminating the need for persistent SSH access.
#
# 5. **User Data**:
#    - User data is not applied in stage/prod environments as the golden AMI contains all necessary configurations.
#    - For dev or debugging purposes, user data can reference scripts from the `scripts_bucket_name` variable.
#
# 6. **Monitoring and Optimization**:
#    - CloudWatch monitoring and EBS optimization are enabled for better performance and visibility.
#
# 7. **Automation**:
#    - Updates to the AMI in the S3 metadata file (`latest-ami.json`) are automatically reflected in the Launch Template.
#    - To automate updates, configure an EventBridge rule or include this step in your CI/CD pipeline.