# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# This file defines key configurations for bucket policies, CORS, and lifecycle rules to ensure security, compliance, and functionality.

# --- CORS Configuration for WordPress Media Bucket --- #
# Configures Cross-Origin Resource Sharing (CORS) rules for the WordPress media bucket.
# These rules specify the headers, methods, and origins that are allowed for cross-origin requests.
# Note: Restricting CORS parameters enhances security by limiting access to specific origins, headers, and methods.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  bucket = aws_s3_bucket.wordpress_media.id # Target bucket for CORS configuration

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"] # Restrict headers to those required by the application.
    # Examples:
    # - Authorization: Required if your app uses tokens for authentication.
    # - Content-Type: Allows handling specific content types like JSON, images, etc.

    allowed_methods = ["GET", "POST"] # Restrict methods to those necessary for the application.
    # - GET: For fetching media files.
    # - POST: For uploading files to the bucket.

    allowed_origins = ["*"] # Allow all origins initially (update to specific domains like ["https://yourwebsite.com"] for better security).

    max_age_seconds = 3000 # Cache CORS preflight responses for 3000 seconds (reduce unnecessary preflight requests).
    # Adjust max_age_seconds based on your application's requirements.
  }
}

# --- Bucket Policies --- #
# Deny public access and enforce HTTPS/TLS for secure communication.

## Deny public access to all buckets
resource "aws_s3_bucket_policy" "deny_public_access" {
  for_each = {
    wordpress_media   = aws_s3_bucket.wordpress_media
    wordpress_scripts = aws_s3_bucket.wordpress_scripts
    terraform_state   = aws_s3_bucket.terraform_state
    logging           = aws_s3_bucket.logging
  }

  bucket = each.value.id # Target bucket for the policy

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
            "aws:SecureTransport" = false # Deny access if not using HTTPS
          }
        }
      }
    ]
  })
}

## Enforce HTTPS for specific buckets
resource "aws_s3_bucket_policy" "force_https" {
  for_each = local.bucket_map # Target buckets
  bucket   = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false" # Deny non-secure transport
          }
        }
      }
    ]
  })
}

# --- Logging Bucket Policy --- #
# Allows S3 logging service to write logs to the logging bucket.
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  bucket = aws_s3_bucket.logging.id # Logging bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLoggingWrite",
        Effect    = "Allow",
        Principal = { Service = "logging.s3.amazonaws.com" }, # S3 logging service
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.logging.id}/*"
      }
    ]
  })
}

# --- Lifecycle Policies --- #
# Manage noncurrent object versions and incomplete uploads for better cost control and compliance.

## Define buckets requiring lifecycle configurations
locals {
  buckets_with_lifecycle = {
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    terraform_state   = aws_s3_bucket.terraform_state.id
    logging           = aws_s3_bucket.logging.id
  }
}

## Apply lifecycle rules to each bucket
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = local.buckets_with_lifecycle

  bucket = each.value # Target bucket

  # Rule to expire noncurrent object versions
  rule {
    id     = "retain-versions" # Rule ID
    status = "Enabled"         # Enable the rule

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Retain noncurrent versions for this duration
    }
  }

  # Rule to abort incomplete uploads
  rule {
    id     = "abort-incomplete-uploads" # Rule ID
    status = "Enabled"                  # Enable the rule

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort uploads after 7 days of inactivity
    }
  }
}

# --- Key Highlights and Recommendations --- #
# 1. **CORS Configuration**:
#    - Necessary for cross-origin requests (e.g., accessing WordPress media from a different domain).
#    - Use specific origins instead of `*` for better security in production.

# 2. **Public Access Denial**:
#    - Deny all public access to buckets for enhanced security.
#    - Combined with the `force_https` policy to ensure encrypted communication.

# 3. **Lifecycle Rules**:
#    - Cost-efficient management of storage by cleaning up noncurrent versions and incomplete uploads.
#    - Ensure compliance with data retention policies.

# 4. **Logging Policy**:
#    - Allows the logging service to store access logs in the logging bucket.
#    - Helps in monitoring and auditing bucket activities.
