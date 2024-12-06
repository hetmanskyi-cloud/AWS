# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project.
# Buckets include:
# 1. terraform_state: To store the Terraform state file.
# 2. wordpress_media: To store media assets for WordPress.
# 3. wordpress_scripts: To store scripts related to WordPress setup.
# 4. logging: To store logs for all buckets.

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

# --- Notes --- #
# 1. Cross-Region Replication is intentionally not used as it is unnecessary for the current project scope.
# 2. The `depends_on` directive ensures that the logging bucket is created before other buckets, allowing logging configurations to function without errors.
# 3. Unique bucket names prevent conflicts in the global namespace of S3.
