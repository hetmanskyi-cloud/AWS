# --- ASG Launch Template Configuration --- #
# This configuration provisions instances for the Auto Scaling Group (ASG)
# using a standard AMI and the deploy_wordpress.sh script to install and configure WordPress.

locals {
  # WordPress configuration parameters passed to the deployment script
  wp_config = {
    DB_HOST         = var.db_host
    DB_PORT         = var.db_port
    WP_TITLE        = var.wp_title
    PHP_VERSION     = var.php_version
    PHP_FPM_SERVICE = "php${var.php_version}-fpm"
    REDIS_HOST      = var.redis_endpoint
    REDIS_PORT      = var.redis_port
    AWS_LB_DNS      = var.alb_dns_name
  }

  # Healthcheck file used for the ALB target group
  healthcheck_file = "healthcheck.php"

  # Path to the healthcheck file stored in the S3 scripts bucket
  healthcheck_s3_path = "s3://${var.scripts_bucket_name}/wordpress/${local.healthcheck_file}"

  # Retry parameters used in the deployment script when waiting for service readiness
  retry_config = {
    MAX_RETRIES    = 30
    RETRY_INTERVAL = 10
  }

  # Path to the WordPress deployment script stored in the S3 scripts bucket
  wordpress_script_path = "s3://${var.scripts_bucket_name}/wordpress/deploy_wordpress.sh"

  # Local deployment script content used for uploading to S3
  script_content = file(var.deploy_script_path)

  # Rendered user_data script passed to the EC2 instance at launch
  rendered_user_data = templatefile(
    "${path.module}/../../templates/user_data.sh.tpl",
    {
      wp_config              = local.wp_config
      aws_region             = var.aws_region
      wordpress_script_path  = local.wordpress_script_path
      script_content         = local.script_content
      retry_max_retries      = local.retry_config.MAX_RETRIES
      retry_retry_interval   = local.retry_config.RETRY_INTERVAL
      healthcheck_s3_path    = local.healthcheck_s3_path
      wordpress_secrets_name = var.wordpress_secrets_name
      redis_auth_secret_name = var.redis_auth_secret_name
      enable_cloudwatch_logs = var.enable_cloudwatch_logs
      cloudwatch_log_groups  = var.cloudwatch_log_groups

      # Default deployment paths used in deploy_wordpress.sh
      WP_TMP_DIR = "/tmp/wordpress-setup"
      WP_PATH    = "/var/www/html"
    }
  )
}

# --- ASG Launch Template for ASG --- #
resource "aws_launch_template" "asg_launch_template" {
  # Template Settings
  # The name_prefix ensures unique naming for launch templates.
  name_prefix = "${var.name_prefix}-asg-launch-template"
  description = "Launch template for ASG instances with auto-scaling configuration"

  # Lifecycle Management
  # Ensure a new launch template is created before the old one is destroyed during updates.
  lifecycle {
    create_before_destroy = true # Ensure no downtime during template updates
  }

  # Create new version on each update
  update_default_version = true

  # Security Group
  # Reference the ASG Security Group.
  vpc_security_group_ids = [aws_security_group.asg_security_group.id] # Security groups for networking

  # Instance Specifications
  # Define the AMI ID and instance type.
  image_id      = var.ami_id        # AMI ID specified in terraform.tfvars
  instance_type = var.instance_type # Instance type (e.g., t2.micro for AWS Free Tier)
  key_name      = var.ssh_key_name  # SSH key pair name for secure instance access (optional)

  # Block Device Mappings
  # Configure the root EBS volume with encryption enabled if enabled via `enable_ebs_encryption`.
  block_device_mappings {
    device_name = "/dev/sda1" # Root volume device name for image AMIs
    ebs {
      volume_size           = var.volume_size                                    # Volume size in GiB
      volume_type           = var.volume_type                                    # Volume type (e.g., gp2, gp3)
      encrypted             = var.enable_ebs_encryption                          # Enable volume encryption using the specified KMS key if enabled
      kms_key_id            = var.enable_ebs_encryption ? var.kms_key_arn : null # Use KMS key for encryption.
      delete_on_termination = true                                               # Automatically delete volume on instance termination
    }
  }

  # Security and Metadata Settings
  # Control instance termination and metadata access settings.
  # Prevent accidental termination of instances via API (useful in production)
  disable_api_termination = false # Set to true in production to prevent manual terminations

  # Defines the behavior when an instance is shut down via OS commands (e.g., `shutdown -h now`)
  instance_initiated_shutdown_behavior = "terminate" # Ensures instance is fully terminated upon shutdown

  # Metadata Options for Security
  # Enforce IMDSv2 for enhanced security:
  # - Protects against SSRF attacks (Server-Side Request Forgery)
  # - Prevents unauthorized access to instance metadata
  # - Requires all applications accessing metadata to use signed requests
  metadata_options {
    http_endpoint               = "enabled"  # Enable instance metadata endpoint (required for IMDSv2)
    http_tokens                 = "required" # Enforce IMDSv2 (all metadata requests must be signed)
    http_put_response_hop_limit = 2          # checkov:skip=CKV_AWS_341: Required for ALB/ASG use case (proxy headers)
    instance_metadata_tags      = "enabled"  # Allow retrieval of instance tags from metadata
  }

  # Monitoring and EBS Optimization
  # Enable monitoring and optimization for higher performance.
  monitoring {
    enabled = false # Enable detailed CloudWatch monitoring (may incur additional costs)
  }
  ebs_optimized = false # Enable EBS optimization for better disk I/O performance (recommended for production workloads)
  # Note: Might be unnecessary for t2.micro or very small instances

  # IAM Instance Profile
  # Attach an IAM instance profile to manage permissions for the instance.
  iam_instance_profile {
    name = aws_iam_instance_profile.asg_instance_profile.name # IAM instance profile from asg/iam.tf
  }

  # Tag Specifications
  # Tags are applied to ASG instances created with this Launch Template.
  # The tag `Name` is specific to instances and does not need to match the Launch Template resource name.
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name                  = "${var.name_prefix}-asg-instance-${var.environment}"
      WordPressScriptSource = "s3"
    })
  }

  # Dependency and Error Handling
  depends_on = [
    aws_iam_instance_profile.asg_instance_profile,
    aws_security_group.asg_security_group
  ]

  # User Data
  # Provides an installation and configuration script for WordPress.
  user_data = base64encode(local.rendered_user_data)
}

# --- Notes --- #
# 1. **AMI Selection**:
#    - A standard Amazon Linux or Ubuntu AMI is used, with WordPress installed via a deployment script.
#    - The AMI ID must be defined explicitly in terraform.tfvars.
#
# 2. **User Data**:
#    - The user_data script is dynamically rendered using a template and includes only essential logic.
#    - The deploy_wordpress.sh script is downloaded from the 'scripts' S3 bucket and executed during instance bootstrap.
#    - All scripts and templates (including wp-config and healthcheck) must be available in the 'scripts' S3 bucket.
#    - CloudWatch Logs integration is optionally enabled via `enable_cloudwatch_logs`; log group names must be passed via `cloudwatch_log_groups`.
#    - IMPORTANT: The 'scripts' bucket must be enabled in terraform.tfvars or EC2 initialization will fail.
#
# 3. **SSH Access**:
#    - Temporary SSH access can be enabled for debugging using the `enable_ssh_access` variable.
#    - In production, restrict SSH access to trusted IP ranges via the ASG security group configuration.
#
# 4. **SSM Management**:
#    - All instances are fully managed via AWS Systems Manager (SSM).
#    - This removes the need for direct SSH access and provides centralized access control and auditing.
#
# 5. **Monitoring and Optimization**:
#    - CloudWatch monitoring and EBS optimization can be enabled for improved performance and observability.
#    - When CloudWatch Logs are enabled, custom log groups (user-data, Nginx, PHP-FPM, WordPress, etc.) are configured automatically.
#    - These settings can be adjusted depending on the instance type and workload requirements.
#
# 6. **Automation**:
#    - To support automatic updates or rolling deployments, consider integrating this module into a CI/CD pipeline or EventBridge workflow.
#
# 7. **Healthcheck Integration**:
#    - A fixed health check file `healthcheck.php` is expected to be available in the S3 scripts bucket.
#    - The file is downloaded and placed in the WordPress root for ALB target group health checking.
#    - Its name and location are passed via user_data variables.
#
# 8. **Critical Considerations**:
#    - Ensure all required variables for WordPress setup are correctly passed to the user_data template.
#    - Missing or incorrect values may silently cause the bootstrap process to fail.
#
# 9. **AMI Updates and Rolling Deployments**:
#    - Periodically update the AMI ID to include the latest OS and security updates.
#    - Rolling updates in the ASG can be configured to apply changes with zero downtime.
#
# 10. **AWS Secrets Manager**:
#     - WordPress, database, and Redis credentials are securely stored in AWS Secrets Manager.
#     - These secrets are **not injected directly into user_data** for security reasons.
#     - Instead, they are retrieved **at runtime by the `deploy_wordpress.sh` script**
#       using the `aws secretsmanager get-secret-value` command.
#     - Only non-sensitive configuration variables are exported in user_data.
#     - Ensure the instance profile includes `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` permissions.
#
# 11. **EBS Encryption**:
#     - Root EBS volumes are encrypted with a customer-managed KMS key (`kms_key_arn`).
#     - Encryption is controlled via the `enable_ebs_encryption` variable in terraform.tfvars.
#     - Required KMS key permissions are configured in the kms module (for EC2 and AutoScaling).
#     - Volume is deleted on termination to prevent data persistence outside the ASG lifecycle.