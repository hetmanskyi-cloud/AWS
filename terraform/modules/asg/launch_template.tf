# --- ASG Launch Template Configuration --- #
# This configuration provisions instances for the Auto Scaling Group (ASG)
# using a standard AMI and the deploy_wordpress.sh script to install and configure WordPress.

locals {
  db_config = {
    DB_NAME         = var.db_name
    DB_USERNAME     = var.db_username
    DB_USER         = var.db_username
    DB_PASSWORD     = var.db_password
    DB_HOST         = var.db_host
    PHP_VERSION     = var.php_version
    PHP_FPM_SERVICE = "php${var.php_version}-fpm"
    REDIS_HOST      = var.redis_endpoint # ElastiCache module output for Redis endpoint
    REDIS_PORT      = var.redis_port
  }

  # Defines the source of the WordPress deployment script (S3 bucket or local path).
  wordpress_script_path = var.enable_s3_script ? "s3://${var.scripts_bucket_name}/wordpress/deploy_wordpress.sh" : "${path.root}/scripts/deploy_wordpress.sh"
}

# --- ASG Launch Template for ASG --- #
resource "aws_launch_template" "asg_launch_template" {
  # --- Template Settings --- #
  # The name_prefix ensures unique naming for launch templates.
  name_prefix = "${var.name_prefix}-asg-launch-template"
  description = "Launch template for ASG instances with auto-scaling configuration"

  # --- Lifecycle Management --- #
  # Ensure a new launch template is created before the old one is destroyed during updates.
  lifecycle {
    create_before_destroy = true # Ensure no downtime during template updates
  }

  # --- Instance Specifications --- #
  # Define the AMI ID and instance type.
  image_id      = var.ami_id        # AMI ID specified in terraform.tfvars
  instance_type = var.instance_type # Instance type (e.g., t2.micro for AWS Free Tier)
  key_name      = var.ssh_key_name  # SSH key pair name for secure instance access (optional)

  # --- Block Device Mappings --- #
  # Configure the root EBS volume with encryption enabled if enabled via `enable_ebs_encryption`.
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume device name for image AMIs
    ebs {
      volume_size           = var.volume_size                                    # Volume size in GiB
      volume_type           = var.volume_type                                    # Volume type (e.g., gp2, gp3)
      encrypted             = var.enable_ebs_encryption                          # Enable volume encryption using the specified KMS key if enabled
      kms_key_id            = var.enable_ebs_encryption ? var.kms_key_arn : null # Use KMS key for encryption.
      delete_on_termination = true                                               # Automatically delete volume on instance termination
    }
  }

  # --- Security and Metadata Settings --- #
  # Enable instance metadata options and set termination behavior.
  disable_api_termination              = false       # Allow API termination
  instance_initiated_shutdown_behavior = "terminate" # Terminate instance on shutdown
  metadata_options {
    http_endpoint               = "enabled"  # Enable instance metadata endpoint
    http_tokens                 = "required" # Enforce IMDSv2 for metadata security
    http_put_response_hop_limit = 1          # # Consider the route through ALB
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags for better tracking.
  }

  # --- Monitoring and EBS Optimization --- #
  # Enable monitoring and optimization for higher performance.
  monitoring {
    enabled = true # Enable detailed CloudWatch monitoring (may incur additional costs)
  }
  ebs_optimized = true # Enable EBS optimization for the instance

  # --- IAM Instance Profile --- #
  # Attach an IAM instance profile to manage permissions for the instance.
  iam_instance_profile {
    name = aws_iam_instance_profile.asg_instance_profile.name # IAM instance profile from asg/iam.tf
  }

  # --- Network Interface Configuration --- #
  # Deny public IPs and set security groups for instance networking.
  network_interfaces {
    associate_public_ip_address = var.enable_public_ip                       # Enable/Disable public IPs
    delete_on_termination       = true                                       # Delete interface on termination
    security_groups             = [aws_security_group.asg_security_group.id] # Security groups for networking
  }

  # --- Tag Specifications --- #
  # Tags are applied to ASG instances created with this Launch Template.
  # The tag `Name` is specific to instances and does not need to match the Launch Template resource name.
  tag_specifications {
    resource_type = "instance" # Apply tags to ASG instances created with this template
    tags = {
      Name        = "${var.name_prefix}-asg-instance" # Instance name tag
      Environment = var.environment                   # Environment tag (e.g., dev, stage, prod)
    }
  }

  # --- User Data --- #
  # Provides an installation and configuration script for WordPress.
  user_data = base64encode(templatefile(local.wordpress_script_path, local.db_config))
}

# --- Notes --- #

# 1. **AMI Selection**:
#    - A standard Amazon Linux or Ubuntu AMI is used, with WordPress installed via the script.
#    - AMI ID must be specified in terraform.tfvars.
#
# 2. **User Data**:
#    - The deploy_wordpress.sh script configures the instance with Nginx, PHP, and WordPress.
#    - User data is passed encoded to ensure correct processing.
#
# 3. **Public IPs**:
#    - For increased security, public IP addresses can be disabled for all ASG instances.
#
# 4. **SSH Access**:
#    - Temporary SSH access can be enabled for debugging or maintenance using the `enable_ssh_access` variable in `terraform.tfvars`.
#    - For better control, restrict SSH to specific IP ranges in prod via `asg/security_group.tf`.
#
# 5. **SSM Management**:
#    - All instances are fully manageable via AWS Systems Manager (SSM), eliminating the need for persistent SSH access.
#
# 6. **Monitoring and Optimization**:
#    - CloudWatch monitoring and EBS optimization are enabled for better performance and visibility.
#
# 7. **Automation**:
#    - To automate updates, configure an EventBridge rule or include this step in your CI/CD pipeline.
#
# 8. **Critical Considerations**:
#    - Ensure all variables in the deploy_wordpress.sh script are passed correctly via templatefile function.