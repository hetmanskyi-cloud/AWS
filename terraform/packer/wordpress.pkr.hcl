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

# --- Tagging Variables (Aligned with Makefile) --- #

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

# --- Locals --- #

locals {
  # Generates a timestamp for creating a unique AMI name (e.g., 20231027123045).
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# --- Source Configuration --- #

source "amazon-ebs" "wordpress" {
  ami_name      = "wordpress-golden-ami-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region

  # Connection settings
  ssh_username  = "ubuntu"

  # Base Image Filter (Ubuntu 24.04 LTS Noble)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  # Tags for the created AMI (Matches Makefile 'create-ami' target)
  tags = {
    Name        = "wordpress-golden-ami-${local.timestamp}"
    Environment = var.ami_golden_tag
    Application = var.application
    Component   = var.component
    Project     = var.project
    Owner       = var.owner
    # Extra metadata useful for tracking
    OS          = "Ubuntu 24.04 LTS"
    PHP         = var.php_version
    WordPress   = var.wordpress_version
    BuiltBy     = "Packer"
  }
}

# --- Build Process --- #

build {
  sources = ["source.amazon-ebs.wordpress"]

  # 1. Install Ansible on the build instance
  # We use 'ansible-local' so we need Ansible installed on the target machine.
  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "echo 'Waiting for cloud-init...'",
      "/usr/bin/cloud-init status --wait",
      "echo 'Installing Ansible...'",
      "sudo apt-get update",
      "sudo apt-get install -y software-properties-common ansible python3-pip unzip"
    ]
  }

  # 2. Install Ansible Collections
  # Required for some tasks in the playbook (even if we skip S3, good to have dependencies met).
  provisioner "shell" {
    inline = [
      "ansible-galaxy collection install community.aws"
    ]
  }

  # 3. Upload Healthcheck Script
  # We upload this directly to avoid needing S3 credentials/permissions during the Packer build.
  provisioner "file" {
    source      = "../scripts/healthcheck.php"
    destination = "/tmp/healthcheck.php"
  }

  # 4. Run Ansible Playbook (Software Stack Only)
  # Installs Nginx, PHP, WP-CLI, etc.
  # Skips: DB connection checks, WordPress config generation, S3 downloads.
  provisioner "ansible-local" {
    playbook_file   = "../ansible/playbooks/install-wordpress.yml"
    galaxy_file     = "../ansible/requirements.yml"

    # Skip tags that require runtime environment (DB, S3, Secrets)
    extra_arguments = [
      "--skip-tags", "db-wait,db-check,install,config,healthcheck,cleanup",
      "--extra-vars", "wordpress_version=${var.wordpress_version} enable_cloudwatch_logs=false site_url=http://localhost"
    ]

    # Provide mock structure for 'wp_config' variable which is required by the playbook
    # JSON structure must match what is expected in templates (php_version, etc.)
    vars = {
      wp_config = {
        PHP_VERSION = var.php_version
        DB_HOST     = "localhost"
        DB_PORT     = 3306
        REDIS_HOST  = "localhost"
        REDIS_PORT  = 6379
        WP_TITLE    = "Golden AMI Build"
        WP_DEBUG    = false
      }
      # Dummy values for required variables to prevent Ansible errors
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
      enable_cloudwatch_logs   = false
      vpc_cidr_block           = "10.0.0.0/16"
      # Keys
      auth_key          = "build"
      secure_auth_key   = "build"
      logged_in_key     = "build"
      nonce_key         = "build"
      auth_salt         = "build"
      secure_auth_salt  = "build"
      logged_in_salt    = "build"
      nonce_salt        = "build"
    }
  }

  # 5. Move Healthcheck & Set Permissions
  # Since we skipped the 'healthcheck' tag in Ansible, we move the file manually.
  provisioner "shell" {
    inline = [
      "echo 'Deploying healthcheck.php...'",
      "sudo mv /tmp/healthcheck.php /var/www/html/healthcheck.php",
      "sudo chown www-data:www-data /var/www/html/healthcheck.php",
      "sudo chmod 0644 /var/www/html/healthcheck.php"
    ]
  }

  # 6. Run Hardening Script
  # Uses the project's standard hardening script (UFW, SSH config, cleanup).
  provisioner "shell" {
    script = "../scripts/prepare-golden-ami.sh"
    execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  }

  # 7. Run Smoke Tests
  # Verifies the image integrity (firewall status, service status, cleanup) before creating the AMI.
  # This mimics the 'make test-ami' step.
  provisioner "shell" {
    script = "../scripts/smoke-test-ami.sh"
    execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  }
}
