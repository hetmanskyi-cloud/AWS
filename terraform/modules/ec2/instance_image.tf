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
# Selects a random subnet from the provided list of public subnet IDs
resource "random_integer" "subnet_selector" {
  min = 0
  max = length(var.public_subnet_ids) - 1 # Index range of the subnet list
}

# --- EC2 Instance for Golden Image Creation --- #
# This instance is used only in the dev environment to create golden images for ASG.
# This instance is managed via AWS Systems Manager (SSM).
# SSH access (if enabled) is temporary for setup and debugging.
resource "aws_instance" "instance_image" {
  count = var.environment == "dev" ? 1 : 0 # Created only in dev environment

  # General configuration
  ami           = var.ami_id                                                            # AMI ID for the instance
  instance_type = var.instance_type                                                     # EC2 instance type (e.g., t2.micro)
  subnet_id     = element(var.public_subnet_ids, random_integer.subnet_selector.result) # Randomly select a public subnet
  key_name      = var.enable_ssh_access ? var.ssh_key_name : null                       # Optional SSH key name based on enable_ssh_access

  # Root Block Device Configuration
  root_block_device {
    volume_size           = var.volume_size # Disk size in GiB
    volume_type           = var.volume_type # Disk type (e.g., gp2)
    delete_on_termination = true            # Automatically delete volume on termination
    encrypted             = true            # Enable encryption for the root volume
  }

  # Network Configuration
  # Security group for instance networking
  # SSM Access: Instance is managed via AWS Systems Manager (SSM), eliminating the need for SSH in production.
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id] # Security group for instance networking

  # Metadata Configuration
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata endpoint
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1          # Restrict metadata access
    instance_metadata_tags      = "enabled"  # Enable instance metadata tags
  }

  # Monitoring and Optimization
  monitoring                           = true        # Enable detailed CloudWatch monitoring
  ebs_optimized                        = true        # Optimize EBS performance
  disable_api_termination              = false       # Allow termination via API
  instance_initiated_shutdown_behavior = "terminate" # Terminate instance on shutdown

  # User Data Script
  # Initializes the instance for WordPress setup.
  user_data = base64encode(templatefile("${path.root}/scripts/deploy_wordpress.sh", local.db_config))

  # Tag Specifications
  tags = {
    Name        = "${var.name_prefix}-instance-image" # Instance name tag
    Environment = var.environment                     # Environment tag (e.g., dev, stage, prod)
  }

  # --- Lifecycle Configuration --- #
  # This ensures the instance is destroyed before a new one is created, avoiding overlap.
  lifecycle {
    create_before_destroy = false # Create new instance only after the old one is destroyed
  }
}

# --- Notes --- #
# 1. This instance is created only in the dev environment for generating golden images.
# 2. A public IP is required for updates, patching, and configuration before creating the AMI.
# 3. The subnet is selected randomly from the provided list of public subnet IDs.
# 4. SSH access is temporarily enabled in dev via `enable_ssh_access`, but all operational management should rely on AWS Systems Manager (SSM).
# 5. For security, `enable_ssh_access` defaults to `false` in all environments except for debugging purposes in dev.
# 6. The user_data script sets up the instance for WordPress deployment and configuration.
# 7. IMDSv2 is enforced for enhanced security of instance metadata.
# 8. Monitoring and EBS optimization are enabled for better performance and visibility.
# 9. SSH access is conditional and can be enabled or disabled via `enable_ssh_access` variable.