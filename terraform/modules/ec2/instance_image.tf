# --- EC2 Instance for Golden Image Creation --- #
# This file defines the configuration for an EC2 instance used to prepare a golden image.
# - Automatically created in the dev environment for testing and debugging.
# - In stage/prod, created periodically using EventBridge for updates and maintenance.

locals {
  db_config = {
    DB_NAME         = var.db_name
    DB_USERNAME     = var.db_username
    DB_USER         = var.db_username
    DB_PASSWORD     = var.db_password
    DB_HOST         = var.db_host
    PHP_VERSION     = var.php_version
    PHP_FPM_SERVICE = "php${var.php_version}-fpm"
    REDIS_HOST      = var.redis_endpoint
    REDIS_PORT      = var.redis_port
  }
}

# --- Random Integer for Subnet Selection --- #
# Selects a random subnet from the provided list of public subnet IDs.
resource "random_integer" "subnet_selector" {
  min = 0
  max = length(var.public_subnet_ids) - 1 # Index range of the subnet list.
}

# --- Golden Image EC2 Instance --- #
resource "aws_instance" "instance_image" {
  count = var.environment == "dev" || var.environment == "stage" || var.environment == "prod" ? 1 : 0

  # General configuration
  ami           = var.ami_id                                                            # AMI ID for the instance
  instance_type = var.instance_type                                                     # EC2 instance type (e.g., t2.micro)
  subnet_id     = element(var.public_subnet_ids, random_integer.subnet_selector.result) # Randomly select a public subnet
  key_name      = var.enable_ssh_access ? var.ssh_key_name : null                       # SSH key based on `enable_ssh_access`

  # Root Block Device Configuration
  root_block_device {
    volume_size           = var.volume_size # Disk size in GiB
    volume_type           = var.volume_type # Disk type (e.g., gp2)
    delete_on_termination = true            # Automatically delete volume on termination
    encrypted             = true            # Enable encryption for the root volume
  }

  # IAM Instance Profile:
  # Automatically attaches the EC2 role (`ec2_role`) to the instance.
  # The role provides temporary credentials for accessing AWS services like S3, CloudWatch, and SSM.
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  # Network Configuration
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id] # Security group for instance networking.

  # Metadata Configuration
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata endpoint.
    http_tokens                 = "required" # Enforce IMDSv2 for metadata security.
    http_put_response_hop_limit = 1          # Restrict metadata access to one hop.
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags.
  }

  # Monitoring and Optimization
  monitoring                           = true        # Enable detailed CloudWatch monitoring.
  ebs_optimized                        = true        # Optimize EBS performance.
  disable_api_termination              = false       # Allow termination via API.
  instance_initiated_shutdown_behavior = "terminate" # Terminate instance on shutdown.

  # User Data Script
  # Initializes the instance for WordPress setup.
  user_data = var.environment == "dev" ? base64encode(templatefile("${path.root}/scripts/deploy_wordpress.sh", local.db_config)) : base64encode(templatefile("s3://${var.scripts_bucket_name}/deploy_wordpress.sh", local.db_config))

  # Tag Specifications
  tags = {
    Name        = "${var.name_prefix}-instance-image" # Instance name tag.
    Environment = var.environment                     # Environment tag (e.g., dev, stage, prod).
  }

  # Lifecycle Configuration
  lifecycle {
    create_before_destroy = false # Avoid overlapping instances.
  }
}

# --- Notes --- #
# 1. This instance is created in dev for generating golden images automatically.
# 2. In stage/prod, EventBridge triggers the instance creation for periodic updates.
# 3. Temporary SSH access is allowed in dev for debugging and restricted in prod via `ssh_allowed_ips`.
# 4. SSM access ensures secure management without requiring persistent SSH access.
# 5. Random subnet selection balances resources across public subnets.
# 6. The user_data script initializes the instance for WordPress deployment, including database and Redis configurations.
# 7. In dev, the `deploy_wordpress.sh` script is loaded locally. In stage/prod, it is sourced from the `scripts` S3 bucket.
# 8. IMDSv2 is enforced to secure instance metadata.
# 9. Monitoring and EBS optimization ensure performance and visibility.
# 10. Automation with EventBridge includes enabling SSH before instance creation and disabling it afterward.

# --- Additional Considerations --- #
# - Ensure the `deploy_wordpress.sh` script is properly uploaded to the `scripts` S3 bucket for stage/prod.
# - In stage/prod it is recommended to check the correctness of the IAM role before using it.
# - Regularly review and update the script to align with infrastructure changes.
# - Use EventBridge to automate lifecycle actions like enabling SSH before instance creation and disabling it afterward.