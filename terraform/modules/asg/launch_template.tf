# --- ASG Launch Template Configuration --- #
# This configuration provisions instances for the Auto Scaling Group (ASG)
# using a standard AMI and the deploy_wordpress.sh script to install and configure WordPress.

locals {
  # WordPress configuration
  wp_config = {
    DB_HOST           = var.db_host
    DB_PORT           = var.db_port
    DB_NAME           = var.db_name
    DB_USER           = var.db_username
    DB_PASSWORD       = var.db_password
    WP_TITLE          = var.wp_title
    WP_ADMIN          = var.wp_admin_user
    WP_ADMIN_PASSWORD = var.wp_admin_password
    WP_ADMIN_EMAIL    = var.wp_admin_email
    PHP_VERSION       = var.php_version
    PHP_FPM_SERVICE   = "php${var.php_version}-fpm"
    REDIS_HOST        = var.redis_endpoint
    REDIS_PORT        = var.redis_port
    AWS_LB_DNS        = var.alb_dns_name
    SECRET_NAME       = var.wordpress_secret_name
  }

  # Health check file selection based on healthcheck_version variable
  healthcheck_file = var.healthcheck_version == "2.0" ? "healthcheck-2.0.php" : "healthcheck-1.0.php"

  # Read the content of the selected healthcheck file from the scripts directory
  healthcheck_content = file("${path.root}/scripts/${local.healthcheck_file}")

  # Base64 encode the healthcheck content
  healthcheck_b64 = base64encode(local.healthcheck_content)

  # Retry configuration for service checks
  retry_config = {
    MAX_RETRIES    = 30 # Maximum number of retry attempts
    RETRY_INTERVAL = 10 # Interval between retries in seconds        
  }

  # Defines the source of the WordPress deployment script
  wordpress_script_path = var.enable_s3_script ? "s3://${var.scripts_bucket_name}/wordpress/deploy_wordpress.sh" : "${path.root}/scripts/deploy_wordpress.sh"

  # --- Script Content --- #
  # If `enable_s3_script` is true, use the script from S3. Otherwise, use the local script.
  script_content = var.enable_s3_script ? "" : file("${path.root}/scripts/deploy_wordpress.sh")

  # Rendered user data, passing all necessary variables to the user_data template.
  rendered_user_data = templatefile(
    # Path to the user data template
    "${path.module}/../../templates/user_data.sh.tpl",
    {
      wp_config               = local.wp_config
      aws_region              = var.aws_region
      enable_s3_script        = var.enable_s3_script
      wordpress_script_path   = local.wordpress_script_path
      script_content          = local.script_content
      retry_max_retries       = local.retry_config.MAX_RETRIES
      retry_retry_interval    = local.retry_config.RETRY_INTERVAL
      healthcheck_file        = local.healthcheck_file
      healthcheck_content_b64 = local.healthcheck_b64
    }
  )
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

  # Create new version on each update
  update_default_version = true

  # --- Security Group --- #
  # Reference the ASG Security Group.
  vpc_security_group_ids = [aws_security_group.asg_security_group.id] # Security groups for networking

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
    http_put_response_hop_limit = 2          # # Consider the route through ALB
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
    arn = aws_iam_instance_profile.asg_instance_profile.arn # IAM instance profile from asg/iam.tf
  }

  # --- Tag Specifications --- #
  # Tags are applied to ASG instances created with this Launch Template.
  # The tag `Name` is specific to instances and does not need to match the Launch Template resource name.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                  = "${var.name_prefix}-asg-instance"
      Environment           = var.environment
      WordPressScriptSource = var.enable_s3_script ? "s3" : "local"
    }
  }

  # --- Dependency and Error Handling --- #
  depends_on = [
    aws_iam_instance_profile.asg_instance_profile,
    aws_security_group.asg_security_group
  ]

  # --- User Data --- #
  # Provides an installation and configuration script for WordPress.
  user_data = base64encode(local.rendered_user_data)
}

# --- Notes --- #
#
# 1. **AMI Selection**:
#    - A standard Amazon Linux or Ubuntu AMI is used, with WordPress installed via the script.
#    - The AMI ID must be specified in terraform.tfvars.
#
# 2. **User Data**:
#    - The deploy_wordpress.sh script configures the instance with Nginx, PHP, and WordPress.
#    - User data is passed encoded (using base64) to ensure correct processing.
#
# 3. **SSH Access**:
#    - Temporary SSH access can be enabled for debugging or maintenance using the `enable_ssh_access` variable in terraform.tfvars.
#    - For better control in production, restrict SSH access to specific IP ranges via the ASG security group settings.
#
# 4. **SSM Management**:
#    - All instances are fully manageable via AWS Systems Manager (SSM), eliminating the need for persistent SSH access.
#
# 5. **Monitoring and Optimization**:
#    - CloudWatch monitoring and EBS optimization are enabled for better performance and visibility.
#
# 6. **Automation**:
#    - To automate updates, configure an EventBridge rule or include this step in your CI/CD pipeline.
#
# 7. **Healthcheck Integration**:
#    - The variable `healthcheck_version` determines which healthcheck file is used.
#    - The chosen file’s name is stored in `healthcheck_file`.
#    - The content of the healthcheck file is read into `healthcheck_content` from the scripts directory.
#    - Both variables are passed to the user_data template, so that the deploy_wordpress.sh script
#      can create the proper ALB health check endpoint.
#
# 8. **Critical Considerations**:
#    - Ensure all variables required by the deploy_wordpress.sh script are passed correctly via the templatefile function.