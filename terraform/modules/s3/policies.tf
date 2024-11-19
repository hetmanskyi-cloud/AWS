# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #

# --- CORS Configuration for WordPress Media Bucket --- #
# Configure CORS rules for the WordPress media bucket to allow cross-origin access
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  bucket = aws_s3_bucket.wordpress_media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"] # Update this if you want to restrict access to specific origins
    max_age_seconds = 3000
  }
}

# --- Bucket Policy to Deny Public Access --- #
# Deny public access to ensure bucket security
resource "aws_s3_bucket_policy" "deny_public_access" {
  for_each = {
    wordpress_media   = aws_s3_bucket.wordpress_media
    wordpress_scripts = aws_s3_bucket.wordpress_scripts
    terraform_state   = aws_s3_bucket.terraform_state
    logging           = aws_s3_bucket.logging
  }

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyPublicAccess",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

# --- Lifecycle Policies for Buckets --- #
# Manage lifecycle settings for all buckets using for_each
locals {
  buckets_with_lifecycle = {
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    terraform_state   = aws_s3_bucket.terraform_state.id
    logging           = aws_s3_bucket.logging.id
  }
}

# Apply lifecycle rules for managing noncurrent object versions
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = local.buckets_with_lifecycle

  bucket = each.value

  rule {
    id     = "retain-versions"
    status = "Enabled"

    # Expire noncurrent object versions after 90 days
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }
}
