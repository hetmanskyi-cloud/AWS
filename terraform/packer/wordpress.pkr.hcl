# --- Packer Configuration for AWS WordPress Golden AMI --- #
# This template defines the process for building a pre-configured, hardened AMI
# for the WordPress application using Ansible for software provisioning.

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# --- Variables --- #

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region where the AMI will be built."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type used for the build process."
}

variable "wordpress_version" {
  type        = string
  default     = "v6.8.2"
  description = "Version of WordPress to install (Git tag)."
}

variable "php_version" {
  type        = string
  default     = "8.3"
  description = "PHP version to install (must match project requirements)."
}

# --- Tagging Variables (Aligned with Project Standards) --- #

variable "project" {
  type        = string
  default     = "AWS"
  description = "Project name tag."
}

variable "owner" {
  type        = string
  default     = "Hetmanskyi"
  description = "Owner tag."
}

variable "application" {
  type        = string
  default     = "wordpress"
  description = "Application tag."
}

variable "component" {
  type        = string
  default     = "asg"
  description = "Component tag."
}

variable "ami_golden_tag" {
  type        = string
  default     = "golden"
  description = "Value for the Environment tag on the AMI."
}

variable "build_timestamp" {
  type        = string
  default     = ""
  description = "Optional timestamp passed from Makefile to sync log filenames with AMI name."
}

# --- Locals --- #

locals {
  # Use provided timestamp or generate a unique one (e.g., 20231027123045).
  timestamp = var.build_timestamp != "" ? var.build_timestamp : regex_replace(timestamp(), "[- TZ:]", "")
}

# --- Source Configuration: Amazon EBS --- #
# Defines the temporary EC2 instance used to build the AMI.

source "amazon-ebs" "wordpress" {
  ami_name      = "wordpress-golden-ami-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region

  # Connection settings: Default Ubuntu user
  ssh_username = "ubuntu"

  # Base Image Filter: Ubuntu 24.04 LTS (Noble Numbat)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  # Tags for the resulting AMI (Enables discovery and automation)
  tags = {
    Name        = "wordpress-golden-ami-${local.timestamp}"
    Environment = var.ami_golden_tag
    Application = var.application
    Component   = var.component
    Project     = var.project
    Owner       = var.owner
    OS          = "Ubuntu 24.04 LTS"
    PHP         = var.php_version
    WordPress   = var.wordpress_version
    BuiltBy     = "Packer"
  }

  # Tags for the temporary builder instance (Helps identify leaked resources)
  run_tags = {
    Name        = "packer-builder-${var.application}-${local.timestamp}"
    Environment = "packer-build"
    Application = var.application
    Component   = var.component
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "Packer"
  }
}

# --- Build Process --- #

build {
  sources = ["source.amazon-ebs.wordpress"]

  # 1. Bootstrap: Install Ansible on the build instance
  # Required because we use 'ansible-local' to execute playbooks on the target machine.
  provisioner "shell" {
    inline = [
      "set -x",
      "export DEBIAN_FRONTEND=noninteractive",
      "echo 'Waiting for cloud-init...'",
      "/usr/bin/cloud-init status --wait",
      "echo 'Cloud-init finished. Waiting 10s for system to settle...'",
      "sleep 10",
      "echo 'Checking for apt locks...'",
      "while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for apt lock...'; sleep 5; done",
      "echo 'Installing Ansible and dependencies...'",
      "sudo apt-get update",
      "sudo apt-get install -y software-properties-common ansible python3-pip unzip awscli curl zip"
    ]
  }

  # 2. Collections: Install required Ansible AWS collections
  provisioner "shell" {
    inline = [
      "mkdir -p /home/ubuntu/.ansible/collections",
      "ansible-galaxy collection install community.aws -p /home/ubuntu/.ansible/collections"
    ]
  }

  # 3. File Upload: Transfer Ansible directory and helper scripts
  provisioner "file" {
    source      = "../ansible"
    destination = "/tmp/ansible"
  }

  provisioner "file" {
    source      = "../scripts/healthcheck.php"
    destination = "/tmp/healthcheck.php"
  }

  # 4. Variables: Generate a JSON variables file for Ansible
  # This avoids complex shell escaping when passing multiple variables.
  provisioner "shell" {
    inline = [
      <<-EOT
      cat <<EOF > /tmp/packer_vars.json
      ${jsonencode({
        wordpress_version      = var.wordpress_version
        enable_cloudwatch_logs = false
        enable_db_wait         = false
        enable_redis_wait      = false
        site_url               = "http://localhost"
        wp_config = {
          PHP_VERSION = var.php_version
          DB_HOST     = "localhost"
          DB_PORT     = 3306
          REDIS_HOST  = "localhost"
          REDIS_PORT  = 6379
          WP_TITLE    = "Golden AMI Build"
          WP_DEBUG    = false
        }
        # Dummy values for required variables to prevent Ansible syntax errors
        db_user                  = "build"
        db_password              = "build"
        db_name                  = "build"
        redis_auth_token         = "build"
        wp_admin_user            = "build"
        wp_admin_email           = "build@example.com"
        wp_admin_password_base64 = "YnVpbGQK" # "build" in base64
        scripts_bucket_name      = "placeholder"
        efs_file_system_id       = ""
        efs_access_point_id      = ""
        enable_https             = false
        vpc_cidr_block           = "10.0.0.0/16"
        # Security Keys (Placeholders)
        auth_key                 = "build"
        secure_auth_key          = "build"
        logged_in_key            = "build"
        nonce_key                = "build"
        auth_salt                = "build"
        secure_auth_salt         = "build"
        logged_in_salt           = "build"
        nonce_salt               = "build"
      })}
      EOF
      EOT
    ]
  }

  # 5. Provision: Run Ansible Playbook (Software Stack Only)
  # We skip 'wp-cli' and 'plugins' tags to avoid database-dependent tasks during AMI baking.
  # We keep 'install' to ensure the WordPress codebase is cloned and synchronized.
  provisioner "shell" {
    inline = [
      "cd /tmp/ansible/playbooks",
      "sudo ansible-playbook -i localhost, -c local install-wordpress.yml --skip-tags db-wait,redis-wait,db-check,wp-cli,plugins,healthcheck,cleanup --extra-vars @/tmp/packer_vars.json"
    ]
  }

  # 5.1 Manual Fix: Install WP-CLI binary
  # We install this manually AFTER Ansible ensures PHP is installed.
  # This is needed because the Ansible 'wp-cli' tag is skipped to avoid DB init errors.
  provisioner "shell" {
    inline = [
      "echo 'Installing WP-CLI manually...'",
      "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar",
      "chmod +x wp-cli.phar",
      "sudo mv wp-cli.phar /usr/local/bin/wp",
      "wp --info"
    ]
  }

  # 5.2 Helper: Deploy Healthcheck script
  provisioner "shell" {
    inline = [
      "echo 'Deploying healthcheck.php...'",
      "sudo mv /tmp/healthcheck.php /var/www/html/healthcheck.php",
      "sudo chown www-data:www-data /var/www/html/healthcheck.php",
      "sudo chmod 0644 /var/www/html/healthcheck.php"
    ]
  }

  # 6. Hardening: Run security hardening script
  # Uses 'sudo bash' explicitly because scripts lack shebangs for compatibility.
  provisioner "shell" {
    script          = "../scripts/prepare-golden-ami.sh"
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # 7. Verification: Run Smoke Tests
  # Verifies image integrity (firewall, services, cleanup) before finalization.
  provisioner "shell" {
    script          = "../scripts/smoke-test-ami.sh"
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # 8. Post-Processing: Manifest and Automation
  # This block runs locally on the build host.

  # 8.1 Generate manifest file to capture artifacts reliably
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }

  # 8.2 History Tracking and Terraform Automation
  post-processor "shell-local" {
    inline = [
      "set -e",
      "mkdir -p ../environments/dev/ami_history/logs",

      # Extract AMI ID from manifest using grep/sed (avoids jq dependency)
      # Format in manifest: "artifact_id": "eu-west-1:ami-0123456789abcdef0"
      "AMI_ID=$(grep 'artifact_id' packer-manifest.json | head -n 1 | cut -d':' -f3 | tr -d '\", ')",
      "echo \"Extracted AMI ID: $AMI_ID\"",

      # 1. Update history file (TIMESTAMP - AMI_ID)
      "echo '${local.timestamp} - '$AMI_ID >> ../environments/dev/ami_history/ami_id.txt",

      # 2. Create success log entry
      "echo '[${local.timestamp}] Packer build successful. AMI ID: '$AMI_ID > ../environments/dev/ami_history/logs/packer_build_${local.timestamp}.log",
      "echo 'Successfully added AMI '$AMI_ID' to ../environments/dev/ami_history/ami_id.txt'",

      # 3. Automatically promote AMI to dev and stage environments
      "cd ..",
      "echo 'Updating Terraform variables in dev and stage...'",
      "make use-ami TARGET_ENV=dev SOURCE_ENV=dev",
      "make use-ami TARGET_ENV=stage SOURCE_ENV=dev",

      # 4. Cleanup
      "rm -f packer/packer-manifest.json"
    ]
  }
}

# --- Notes --- #
# 1. Compatibility: Scripts (prepare-golden-ami.sh, smoke-test-ami.sh) must be run with 'sudo bash'
#    because they lack shebangs to remain compatible with Makefile/SSM workflows.
# 2. WP-CLI: Installed manually in Packer to decouple the binary installation from
#    database-dependent WordPress installation tasks in the Ansible playbook.
# 3. Ansible Tags: The 'wp-cli' and 'plugins' tags are skipped during the build to prevent
#    errors when a database is not available. Real initialization happens during instance launch.
# 4. Automation: The post-processor automatically triggers 'make use-ami' to update
#    'terraform.tfvars', making the new AMI immediately ready for deployment.
