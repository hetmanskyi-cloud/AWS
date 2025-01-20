# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project, with dynamic logic for environment and type.
# Buckets include:
# 1. scripts: To store project-related scripts. This bucket is always created.
# 2. logging: To store logs for all buckets. This bucket is always created.
# 3. ami: To store golden AMI images for the project. This bucket is always created.
# 4. terraform_state: To store the Terraform state file.
#    - This bucket is created only if enabled via the variable `enable_terraform_state_bucket`.
# 5. wordpress_media: To store media assets for WordPress site.
#    - This bucket is created only if enabled via the variable `enable_wordpress_media_bucket`.
# 6. replication: Serves as the destination for cross-region replication.
#    - This bucket is created only if enabled via the variable `enable_replication_bucket` and used for replication logic.

# --- Terraform Configuration --- #
# Specifies the required Terraform providers and their versions.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replication]
    }
  }
}

# --- Dynamically Create S3 Buckets --- #
# This resource dynamically creates S3 buckets based on the input `buckets` variable.
# Each entry in `buckets` defines the name and type of the bucket.
# The logic here ensures:
# - Base buckets (e.g., `scripts`, `logging`, `ami`) are always created.
# - Special buckets (e.g., `terraform_state`, `wordpress_media`, `replication`) are created only if enabled via variables.
# Tags are applied to all created buckets for proper identification and organization.

resource "aws_s3_bucket" "buckets" {
  # Iterate through the `buckets` variable, creating a bucket for each entry.
  for_each = var.buckets

  bucket = each.key # Use the bucket name as the unique identifier.

  # Apply tags to identify the environment and bucket name.
  tags = {
    Name        = each.key        # Name tag for the bucket.
    Environment = var.environment # Environment tag (e.g., dev, stage, prod).
  }
  # WARNING: Versioning is disabled for this buckets in `terraform.tfvars`. Objects without versions cannot be recovered.
}

# --- Base S3 Buckets --- #

# --- Scripts S3 Bucket --- #
resource "aws_s3_bucket" "scripts" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-scripts-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-scripts"
    Environment = var.environment
  }
}

# --- WordPress Folder in Scripts Bucket --- #
resource "aws_s3_object" "wordpress_folder" {
  bucket = aws_s3_bucket.scripts.bucket # Specify the bucket where the folder will be created
  key    = "wordpress/"                 # Use a trailing slash to denote a directory

  # Dependency ensures the Scripts bucket is created first
  depends_on = [aws_s3_bucket.scripts]

  # --- Notes --- #
  # 1. The "aws_s3_object" resource creates a logical folder structure in the bucket.
  # 2. While S3 has no true folders, the trailing slash creates a logical directory structure.
}

# --- Deploy WordPress Script --- #
resource "aws_s3_object" "deploy_wordpress_script" {
  bucket       = aws_s3_bucket.scripts.bucket               # The bucket where the script will be stored
  key          = "wordpress/deploy_wordpress.sh"            # The path and name of the script in the bucket
  source       = "${path.root}/scripts/deploy_wordpress.sh" # Path to the local script
  content_type = "text/x-shellscript"                       # MIME type for shell scripts

  # Ensure the scripts bucket is created first
  depends_on = [aws_s3_bucket.scripts]

  # Tags to track the script version
  tags = {
    Name        = "Deploy WordPress Script"
    Environment = var.environment
  }

  # --- Notes --- #
  # 1. This resource uploads the WordPress deployment script to the `scripts` bucket.
  # 2. The `source` attribute points to the local script file to be uploaded.
  # 3. This script is placed under the `wordpress/` folder in the bucket.
  # 4. Terraform does not validate the existence of the `deploy_wordpress.sh` file during the plan phase.
  # 5. Ensure that the file exists at the specified local path (`scripts/deploy_wordpress.sh`) before running `terraform apply`.
  # 6. Missing or incorrect file paths will cause the S3 object upload to fail during the apply phase.
}

# --- Logging S3 Bucket --- #
resource "aws_s3_bucket" "logging" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${var.name_prefix}-logging-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-logging"
    Environment = var.environment
    Purpose     = "Centralized logging for ALB, WAF, other S3 buckets and various AWS resources in their respective folders."
  }
}

# --- AMI S3 Bucket --- #
resource "aws_s3_bucket" "ami" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-ami-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-ami"
    Environment = var.environment
  }
}

# --- Special S3 Buckets --- #

# --- Terraform State S3 Bucket --- #
resource "aws_s3_bucket" "terraform_state" {
  # Enabled via the enable_terraform_state_bucket variable in terraform.tfvars.
  count = var.enable_terraform_state_bucket ? 1 : 0

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-terraform-state-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-terraform-state"
    Environment = var.environment
  }
}

# --- WordPress Media S3 Bucket --- #
resource "aws_s3_bucket" "wordpress_media" {
  # Enabled via the enable_wordpress_media_bucket variable in terraform.tfvars.
  count = var.enable_wordpress_media_bucket ? 1 : 0

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-wordpress-media-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-wordpress-media"
    Environment = var.environment
  }
}

# --- Replication S3 Bucket --- #
# Cross-Region Replication Configuration
# The replication destination bucket is created in the specified `replication_region`.
resource "aws_s3_bucket" "replication" {
  provider = aws.replication
  # Enabled via the enable_replication_bucket variable in terraform.tfvars.
  count = var.enable_replication_bucket ? 1 : 0 # The enable_replication_bucket variable is only used to enable the bucket, not the configuration.

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-replication-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-replication"
    Environment = var.environment
  }
}

# --- S3 Bucket Notifications --- #
# This resource configures S3 bucket notifications for the specified buckets.
# Notifications are sent to the specified SNS topic for events like object creation or deletion.
# Only buckets enabled and present in the `buckets` variable are included in this configuration.
# Disabled buckets are ignored automatically via `for_each` logic.
resource "aws_s3_bucket_notification" "bucket_notifications" {
  # Filter buckets dynamically
  for_each = tomap({
    for key, value in {
      scripts         = aws_s3_bucket.scripts,
      logging         = aws_s3_bucket.logging,
      ami             = aws_s3_bucket.ami,
      terraform_state = var.enable_terraform_state_bucket ? aws_s3_bucket.terraform_state[0] : null,
      wordpress_media = var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0] : null
    } : key => value if value != null
  })

  bucket = each.value.id

  topic {
    topic_arn = var.sns_topic_arn # Notifications are configured for object creation and deletion events using SNS.
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# --- Replication Configuration for Source Buckets --- #
# This resource configures cross-region replication for selected buckets.
# Replication is enabled only when `enable_s3_replication` is `true`.
# Each replicated bucket uses a prefix matching its name for object organization in the destination bucket.
# Buckets that are not enabled are automatically excluded via the `for_each` logic.
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  for_each = var.enable_s3_replication ? tomap({
    for key, bucket_id in {
      scripts         = aws_s3_bucket.scripts.id,
      logging         = aws_s3_bucket.logging.id,
      ami             = aws_s3_bucket.ami.id,
      terraform_state = var.enable_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].id : null,
      wordpress_media = var.enable_wordpress_media_bucket ? aws_s3_bucket.wordpress_media[0].id : null
    } : key => bucket_id if bucket_id != null
  }) : {}

  bucket = each.value
  role   = aws_iam_role.replication_role[0].arn

  rule {
    id     = "${each.key}-replication"
    status = "Enabled"

    filter {
      prefix = "${each.key}/"
    }

    destination {
      bucket        = aws_s3_bucket.replication[0].arn
      storage_class = "STANDARD"
    }
  }

  # --- Notes --- #
  # 1. The source buckets listed in this replication configuration must exist before enabling replication.
  # 2. Ensure that the `replication` destination bucket is accessible and properly configured for cross-region replication.
  # 3. Any misconfigured or inaccessible source or destination buckets may cause Terraform to fail during the apply phase.
  # Ensure that all buckets referenced in this configuration are created and accessible.
}

# --- Random String Configuration --- #
resource "random_string" "suffix" {
  length  = 5     # Length of the random string
  special = false # Exclude special characters
  upper   = false # Exclude uppercase letters
  lower   = true  # Include lowercase letters
  numeric = true  # Include numeric digits
}

# --- Notes --- #
# 1. Replication Configuration:
#    - Replication can be enabled in any environment for testing.
#    - Destination buckets should be pre-configured and accessible.
#
# 2. Bucket Notifications:
#    - Notifications are dynamically applied based on the environment and bucket availability.
#    - Notifications are dynamically applied based on the buckets enabled through variables like `enable_terraform_state_bucket`.
#
# 3. Dependencies:
#    - Use explicit `depends_on` for clarity when resources rely on others.
#
# 4. Unique Naming:
#    - Ensure bucket names remain unique across environments to avoid conflicts.
#
# 5. Logical Structure:
#    - Adjust variables and conditions to match the specific requirements of your project.