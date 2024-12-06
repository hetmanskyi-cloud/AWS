# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project.
# Buckets include:
# 1. terraform_state: To store the Terraform state file.
# 2. wordpress_media: To store media assets for WordPress.
# 3. wordpress_scripts: To store scripts related to WordPress setup.
# 4. logging: To store logs for all buckets.

# --- Local variable: Map of S3 bucket names to their IDs --- #
# This map is used to dynamically create notifications for each bucket.
locals {
  bucket_map = {
    "terraform_state" = {
      id  = aws_s3_bucket.terraform_state.id
      arn = aws_s3_bucket.terraform_state.arn
    }
    "wordpress_media" = {
      id  = aws_s3_bucket.wordpress_media.id
      arn = aws_s3_bucket.wordpress_media.arn
    }
    "wordpress_scripts" = {
      id  = aws_s3_bucket.wordpress_scripts.id
      arn = aws_s3_bucket.wordpress_scripts.arn
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
# 1. Cross-Region Replication is intentionally not used as it is unnecessary for the current project scope.
# 2. The `depends_on` directive ensures that the logging bucket is created before other buckets, allowing logging configurations to function without errors.
# 3. Unique bucket names prevent conflicts in the global namespace of S3.
