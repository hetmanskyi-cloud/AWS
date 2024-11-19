# --- S3 Buckets for the Project --- #

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${lower(var.name_prefix)}-terraform-state-${random_string.suffix.result}"

  depends_on = [aws_s3_bucket.logging]

  tags = {
    Name        = "${var.name_prefix}-terraform-state"
    Environment = var.environment
  }
}

# S3 Bucket for WordPress Media
resource "aws_s3_bucket" "wordpress_media" {
  bucket = "${lower(var.name_prefix)}-wordpress-media-${random_string.suffix.result}"

  depends_on = [aws_s3_bucket.logging]

  tags = {
    Name        = "${var.name_prefix}-wordpress-media"
    Environment = var.environment
  }
}

# S3 Bucket for WordPress Scripts
resource "aws_s3_bucket" "wordpress_scripts" {
  bucket = "${lower(var.name_prefix)}-wordpress-scripts-${random_string.suffix.result}"

  depends_on = [aws_s3_bucket.logging]

  tags = {
    Name        = "${var.name_prefix}-wordpress-scripts"
    Environment = var.environment
  }
}

# S3 Bucket for Logging
resource "aws_s3_bucket" "logging" {
  bucket = "${var.name_prefix}-logging-${random_string.suffix.result}"

  tags = {
    Name        = "${var.name_prefix}-logging"
    Environment = var.environment
  }
}

# --- Random String for Unique Resource Names --- #
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  lower   = true
  numeric = true
}
