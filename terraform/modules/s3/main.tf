# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project.
# Buckets include:
# 1. terraform_state: To store the Terraform state file.
# 2. wordpress_media: To store media assets for WordPress.
# 3. wordpress_scripts: To store scripts related to WordPress setup.
# 4. logging: To store logs for all buckets.

# --- Local variable: Map of S3 bucket names to their IDs --- #
# This map is used to dynamically create notifications for each bucket.
# Includes replication bucket if replication is enabled.
locals {
  bucket_map = merge(
    {
      "terraform_state" = {
        id  = aws_s3_bucket.terraform_state.id # Terraform state bucket
        arn = aws_s3_bucket.terraform_state.arn
      }
      "wordpress_media" = {
        id  = aws_s3_bucket.wordpress_media.id # WordPress media bucket
        arn = aws_s3_bucket.wordpress_media.arn
      }
      "wordpress_scripts" = {
        id  = aws_s3_bucket.wordpress_scripts.id # WordPress scripts bucket
        arn = aws_s3_bucket.wordpress_scripts.arn
      }
      "logging" = {
        id  = aws_s3_bucket.logging.id # Logging bucket
        arn = aws_s3_bucket.logging.arn
      }
    },
    var.enable_s3_replication ? {
      "replication" = {
        id  = aws_s3_bucket.replication[0].id # Replication bucket
        arn = aws_s3_bucket.replication[0].arn
      }
    } : {}
  )
}

# --- Terraform Configuration --- #
# This block defines the required Terraform providers and their versions.
# It ensures compatibility and manages aliases for multiple provider configurations.
# Note: The main AWS provider configuration is defined in the `providers.tf` file in the root/main block.
# This block only specifies requirements and aliases relevant to the S3 module.

terraform {
  required_providers {
    # AWS Provider Configuration
    aws = {
      source                = "hashicorp/aws"   # Specifies the source for the AWS provider (HashiCorp registry)
      version               = "~> 5.0"          # Locks the AWS provider to major version 5.x to avoid breaking changes
      configuration_aliases = [aws.replication] # Allows the use of a named alias (aws.replication) for managing cross-region resources
    }
  }
}

# --- Terraform State S3 Bucket --- #
# This bucket is used to store the Terraform state file.
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

# --- WordPress Media S3 Bucket --- #
# This bucket stores WordPress media files (e.g., images, videos).
resource "aws_s3_bucket" "wordpress_media" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-wordpress-media-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-wordpress-media"
    Environment = var.environment
  }
}

# --- WordPress Scripts S3 Bucket --- #
# This bucket stores scripts required for WordPress deployment and maintenance.
resource "aws_s3_bucket" "wordpress_scripts" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-wordpress-scripts-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-wordpress-scripts"
    Environment = var.environment
  }
}

# --- Logging S3 Bucket --- #
# This bucket stores logs for all other buckets to ensure compliance and auditing.
resource "aws_s3_bucket" "logging" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${var.name_prefix}-logging-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-logging"
    Environment = var.environment
  }
}

# --- Replication S3 Bucket --- #
# This bucket serves as the destination for cross-region replication.
# It is created only when replication is enabled (controlled by `enable_s3_replication`).
resource "aws_s3_bucket" "replication" {
  provider = aws.replication
  count    = var.enable_s3_replication ? 1 : 0

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-replication-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-replication"
    Environment = var.environment
  }
}

# --- Replication Configuration for Source Buckets --- #
# Applies replication rules to the source buckets when replication is enabled.
# Each source bucket will replicate its objects to the replication bucket.
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  provider = aws.replication
  for_each = var.enable_s3_replication ? {
    terraform_state   = aws_s3_bucket.terraform_state.id,
    wordpress_media   = aws_s3_bucket.wordpress_media.id,
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    logging           = aws_s3_bucket.logging.id
  } : {}

  bucket = each.value
  role   = aws_iam_role.replication_role[0].arn

  rule {
    id     = "${each.key}-replication"
    status = "Enabled"

    filter {
      prefix = "" # Replicate all objects; adjust as needed
    }

    destination {
      bucket        = aws_s3_bucket.replication[0].arn
      storage_class = "STANDARD"
    }
  }
}

# --- Random String Resource --- #
# Generates a unique 5-character suffix for bucket names.
resource "random_string" "suffix" {
  length  = 5     # Length of the random string
  special = false # Exclude special characters
  upper   = false # Exclude uppercase letters
  lower   = true  # Include lowercase letters
  numeric = true  # Include numeric digits
}

# --- S3 Bucket Notifications --- #
# Configure notifications for all S3 buckets in the bucket_map.
# Notifications are sent to the specified SNS topic whenever objects are created or deleted in the buckets.
resource "aws_s3_bucket_notification" "bucket_notifications" {
  for_each = local.bucket_map # Iterate over all buckets in the bucket_map

  # S3 bucket to which the notification applies
  bucket = each.value.id

  # Notification configuration for the bucket
  topic {
    topic_arn = var.sns_topic_arn                            # ARN of the SNS topic for notifications
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] # Notify on object creation and deletion
  }
}

# --- Notes --- #
# 1. Cross-Region Replication:
#    - Replication is enabled only when `enable_s3_replication` is set to `true`.
#    - Source buckets replicate their objects to a separate replication bucket.
#    - The replication bucket is created in a different region (see explanation below).
#
# 2. The `depends_on` directive:
#    - Ensures that the logging bucket is created before other buckets.
#    - Avoids configuration errors related to bucket dependencies.
#
# 3. Unique bucket names:
#    - Prevents conflicts in the global namespace of S3.