# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project, with dynamic logic for environment and type.
# Buckets include:
# 1. terraform_state: To store the Terraform state file.
# 2. wordpress_media: To store media assets for WordPress in stage and prod environments.
# 3. scripts: To store project-related scripts.
# 4. logging: To store logs for all buckets.
# 5. ami: To store golden AMI images for the project.
# 6. replication: Serves as the destination for cross-region replication.
#    - This bucket is created only in the `stage` and `prod` environments and when replication is enabled.

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
# - Base buckets are always created.
# - Special buckets are created only in specific environments.
# Each bucket is uniquely identified by its name, which is passed in the `buckets` variable.
# Tags are applied to all created buckets for proper identification and organization.

resource "aws_s3_bucket" "buckets" {
  # Iterate through the `buckets` variable, creating a bucket for each entry.
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  bucket = each.key # Use the bucket name as the unique identifier.

  # Apply tags to identify the environment and bucket name.
  tags = {
    Name        = each.key        # Name tag for the bucket.
    Environment = var.environment # Environment tag (e.g., dev, stage, prod).
  }
}

# --- Base S3 Buckets --- #

# --- Terraform State S3 Bucket --- #
resource "aws_s3_bucket" "terraform_state" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-terraform-state-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-terraform-state"
    Environment = var.environment
  }
}

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

# --- Logging S3 Bucket --- #
resource "aws_s3_bucket" "logging" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${var.name_prefix}-logging-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-logging"
    Environment = var.environment
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

# --- WordPress Media S3 Bucket --- #
resource "aws_s3_bucket" "wordpress_media" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-wordpress-media-${random_string.suffix.result}"
  # Created in stage and prod environments
  count = var.environment == "stage" || var.environment == "prod" ? 1 : 0

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-wordpress-media"
    Environment = var.environment
  }
}

# --- Replication S3 Bucket --- #
# Cross-Region Replication Configuration
# Replication is enabled only if `enable_s3_replication` is set to true.
# The replication destination bucket is created in the specified `replication_region`.
resource "aws_s3_bucket" "replication" {
  provider = aws.replication
  # Create the bucket only if both conditions are true
  count = (var.environment == "stage" || var.environment == "prod") && var.enable_s3_replication ? 1 : 0

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-replication-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-replication"
    Environment = var.environment
  }
}

# --- S3 Bucket Notifications --- #
resource "aws_s3_bucket_notification" "bucket_notifications" {
  for_each = var.environment == "prod" || var.environment == "stage" ? {
    terraform_state = aws_s3_bucket.terraform_state,
    scripts         = aws_s3_bucket.scripts,
    logging         = aws_s3_bucket.logging,
    ami             = aws_s3_bucket.ami,
    wordpress_media = aws_s3_bucket.wordpress_media[0]
    } : {
    terraform_state = aws_s3_bucket.terraform_state,
    scripts         = aws_s3_bucket.scripts,
    logging         = aws_s3_bucket.logging,
    ami             = aws_s3_bucket.ami
  }

  bucket = each.value.id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# Replication Configuration for Source Buckets
# This resource configures cross-region replication for selected buckets.
# Replication is enabled only when `enable_s3_replication` is `true` and the environment is `stage` or `prod`.
# Each replicated bucket uses a prefix matching its name for object organization in the destination bucket.
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  for_each = var.enable_s3_replication && (var.environment == "stage" || var.environment == "prod") ? {
    terraform_state = aws_s3_bucket.terraform_state.id,
    scripts         = aws_s3_bucket.scripts.id,
    logging         = aws_s3_bucket.logging.id,
    ami             = aws_s3_bucket.ami.id,
    wordpress_media = aws_s3_bucket.wordpress_media[0].id
  } : {}

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
}

# --- Random String Configuration ---#
resource "random_string" "suffix" {
  length  = 5     # Length of the random string
  special = false # Exclude special characters
  upper   = false # Exclude uppercase letters
  lower   = true  # Include lowercase letters
  numeric = true  # Include numeric digits
}

# --- Notes --- #
# 1. Bucket Management:
#    - The `buckets` variable in `terraform.tfvars` defines which buckets are created and their types.
#    - Buckets are categorized as "base" or "special" for better flexibility and control.
#
# 2. Special Buckets:
#    - The `wordpress_media` bucket is created in `stage` and `prod` environments.
#    - The `replication` bucket is created in `stage` and `prod` environments when `enable_s3_replication` is `true`.
#
# 3. Logical Structure:
#    - The `buckets` variable is dynamically processed to apply the correct configuration based on the environment and type.
#    - Replication rules and versioning settings are conditionally applied depending on the bucket type and environment.
#
# 4. WordPress Folder:
#    - A logical folder "wordpress/" is created in the `scripts` bucket for organizing WordPress-related scripts.
#
# 5. Notifications:
#    - Notifications are configured for bucket events like object creation and deletion, linked to an SNS topic.
#    - Only existing buckets in the current environment receive notifications.
#
# 6. Dependencies:
#    - Dependencies like the logging bucket are enforced with `depends_on` to ensure proper resource creation order.
#
# 7. Unique Bucket Names:
#    - Bucket names include a random suffix for uniqueness across environments.
#
# 8. Replication Configuration:
#    - Applied only in `stage` and `prod` when `enable_s3_replication` is `true`.
#    - Source buckets replicate objects into distinct prefixes (logical folders) in the replication bucket.