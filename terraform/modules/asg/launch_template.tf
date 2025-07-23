# --- ASG Launch Template Configuration --- #
# This configuration provisions instances for the Auto Scaling Group (ASG)
# using a standard AMI and the deploy_wordpress.sh script to install and configure WordPress.

locals {
  # WordPress configuration parameters for the deployment script (used only in dev).
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
  healthcheck_s3_path = var.environment == "dev" ? "s3://${var.scripts_bucket_name}/wordpress/${local.healthcheck_file}" : null

  # Retry parameters used in the deployment script when waiting for service readiness
  retry_config = {
    MAX_RETRIES    = 30
    RETRY_INTERVAL = 10
  }

  # Path to the WordPress deployment script stored in the S3 scripts bucket
  wordpress_script_path = var.environment == "dev" ? "s3://${var.scripts_bucket_name}/wordpress/deploy_wordpress.sh" : null

  # Local deployment script content used for uploading to S3
  script_content = var.environment == "dev" ? file(var.deploy_script_path) : ""

  # User Data Rendering Logic
  # This block selects the correct user_data template based on the environment and deployment method.
  rendered_user_data = (
    # 1. First, check if the environment is 'dev'.
    var.environment == "dev" ? (
      # 2. If it IS 'dev', check the 'use_ansible_deployment' flag to decide which method to use.
      var.use_ansible_deployment ? templatefile(
        # Use the bootstrapper for Ansible.
        "${path.module}/../../templates/user_data_ansible.sh.tpl",
        {
          # Variables required by the Ansible bootstrapper
          aws_region             = var.aws_region
          wp_config              = jsonencode(local.wp_config)
          wordpress_version      = var.wordpress_version
          public_site_url        = var.public_site_url
          enable_https           = var.enable_https_listener
          scripts_bucket_name    = var.scripts_bucket_name
          efs_file_system_id     = var.efs_file_system_id
          efs_access_point_id    = var.efs_access_point_id
          wordpress_secrets_name = var.wordpress_secrets_name
          rds_secrets_name       = var.rds_secrets_name
          redis_auth_secret_name = var.redis_auth_secret_name
          enable_cloudwatch_logs = var.enable_cloudwatch_logs
          cloudwatch_log_groups  = jsonencode(var.cloudwatch_log_groups)
        }
        ) : templatefile(
        # Use the original user_data script that calls deploy_wordpress.sh.
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
          rds_secrets_name       = var.rds_secrets_name
          redis_auth_secret_name = var.redis_auth_secret_name
          enable_cloudwatch_logs = var.enable_cloudwatch_logs
          cloudwatch_log_groups  = var.cloudwatch_log_groups
          public_site_url        = var.public_site_url
          efs_file_system_id     = var.efs_file_system_id
          efs_access_point_id    = var.efs_access_point_id
          enable_https           = var.enable_https_listener

          # Default deployment paths used in deploy_wordpress.sh
          WP_TMP_DIR = "/tmp/wordpress-setup"
          WP_PATH    = "/var/www/html"

          # EFS paths used in deploy_wordpress.sh
          EFS_UPLOADS_PATH = "/var/www/html/wp-content/uploads"

          # WordPress version tag used for the deployment
          wordpress_version = var.wordpress_version
        }
      )
      ) : (
      # 3. If the environment is not 'dev', use a `user_data_runtime.sh.tpl` script
      templatefile(
        "${path.module}/../../templates/user_data_runtime.sh.tpl",
        {
          # Runtime config for stage/prod; installation is not performed.
          wp_config              = local.wp_config
          aws_region             = var.aws_region
          retry_max_retries      = local.retry_config.MAX_RETRIES
          retry_retry_interval   = local.retry_config.RETRY_INTERVAL
          wordpress_secrets_name = var.wordpress_secrets_name
          rds_secrets_name       = var.rds_secrets_name
          redis_auth_secret_name = var.redis_auth_secret_name
          enable_cloudwatch_logs = var.enable_cloudwatch_logs
          cloudwatch_log_groups  = var.cloudwatch_log_groups
          public_site_url        = var.public_site_url
          wordpress_version      = var.wordpress_version
          WP_PATH                = "/var/www/html"
          efs_file_system_id     = var.efs_file_system_id
          efs_access_point_id    = var.efs_access_point_id
          enable_https           = var.enable_https_listener
          EFS_UPLOADS_PATH       = "/var/www/html/wp-content/uploads"
        }
      )
    )
  )
}

# --- ASG Launch Template for ASG --- #
resource "aws_launch_template" "asg_launch_template" {
  # Template Settings
  # The name_prefix ensures unique naming for launch templates.
  name_prefix = "${var.name_prefix}-asg-launch-template-${var.environment}"
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
      Name = "${var.name_prefix}-asg-instance-${var.environment}"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-asg-volume-${var.environment}"
    })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-asg-nic-${var.environment}"
    })
  }

  # Dependency and Error Handling
  depends_on = [
    aws_iam_instance_profile.asg_instance_profile,
    aws_security_group.asg_security_group
  ]

  # User Data
  # Passes user_data to the instance:
  # - In 'dev', performs full installation (bootstrap) via deployment script.
  # - In other environments, only updates runtime secrets/config for pre-built AMI.
  user_data = base64encode(local.rendered_user_data)
}

# --- Notes --- #
# 1. **AMI Selection**:
#    - In 'dev', a standard Amazon Linux or Ubuntu AMI is used, with WordPress installed at boot.
#    - In 'stage' and 'prod', a pre-built golden AMI with WordPress, Nginx, PHP, and plugins is used.
#    - The AMI ID must be defined explicitly in terraform.tfvars.
#
# 2. **User Data**:
#    - In 'dev', user_data installs and configures WordPress, Nginx, PHP, and plugins via deploy_wordpress.sh and supporting files from S3.
#    - In 'stage'/'prod', user_data only updates runtime secrets and config; no software installation or S3 download is performed.
#    - CloudWatch Logs integration can be enabled with `enable_cloudwatch_logs`; log group names must be passed via `cloudwatch_log_groups`.
#    - IMPORTANT: The 'scripts' bucket must be enabled in terraform.tfvars for dev.
#
# 3. **SSH Access**:
#    - Temporary SSH access for debugging can be enabled via `enable_ssh_access` variable.
#    - In production, restrict SSH access to trusted IPs in the ASG security group.
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
#    - In 'dev', healthcheck.php is downloaded from S3 and placed in the WordPress root for ALB.
#    - In 'stage'/'prod', healthcheck.php is already present in the golden AMI.
#
# 8. **Critical Considerations**:
#    - Ensure all required variables for WordPress and system setup are correctly passed to the user_data template for the respective environment.
#    - Missing or incorrect values may silently cause the bootstrap process to fail.
#
# 9. **AMI Updates and Rolling Deployments**:
#    - Periodically update the AMI ID to include the latest OS and security updates.
#    - Rolling updates in the ASG are configured to apply changes with zero downtime.
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
