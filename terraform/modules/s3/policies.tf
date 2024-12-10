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

# Deny public access to all buckets, including the replication bucket
resource "aws_s3_bucket_policy" "deny_public_access" {
  for_each = merge(
    {
      wordpress_media   = aws_s3_bucket.wordpress_media   # WordPress media bucket
      wordpress_scripts = aws_s3_bucket.wordpress_scripts # WordPress scripts bucket
      terraform_state   = aws_s3_bucket.terraform_state   # Terraform state bucket
      logging           = aws_s3_bucket.logging           # Logging bucket
    },
    var.enable_s3_replication ? { replication = aws_s3_bucket.replication[0] } : {} # Include replication bucket if enabled
  )

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
            "aws:SecureTransport" = "false"
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
        Principal = { Service = "logging.s3.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.logging.id}/*"
      }
    ]
  })
}

# --- Lifecycle Policies --- #
# Manage noncurrent object versions and incomplete uploads for better cost control and compliance.

# Define buckets requiring lifecycle configurations
locals {
  buckets_with_lifecycle = {
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    terraform_state   = aws_s3_bucket.terraform_state.id
    logging           = aws_s3_bucket.logging.id
    replication       = var.enable_s3_replication ? aws_s3_bucket.replication[0].id : null
  }
}

# Apply lifecycle rules to each bucket
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = {
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    terraform_state   = aws_s3_bucket.terraform_state.id
    logging           = aws_s3_bucket.logging.id
  }

  bucket = each.value # Target bucket

  # Rule to expire noncurrent object versions
  rule {
    id     = "${each.key}-retain-versions" # Rule ID
    status = "Enabled"                     # Enable the rule

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Retain noncurrent versions for this duration
    }
  }

  # Rule to abort incomplete uploads
  rule {
    id     = "${each.key}-abort-incomplete-uploads" # Rule ID
    status = "Enabled"                              # Enable the rule

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort uploads after 7 days of inactivity
    }
  }
}

# Additional configuration for replication if enabled
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  count  = var.enable_s3_replication ? 1 : 0
  bucket = aws_s3_bucket.replication[0].id

  # Rule to expire noncurrent object versions
  rule {
    id     = "replication-retain-versions" # Rule ID
    status = "Enabled"                     # Enable the rule

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Retain noncurrent versions for this duration
    }
  }

  # Rule to abort incomplete uploads
  rule {
    id     = "replication-abort-incomplete-uploads" # Rule ID
    status = "Enabled"                              # Enable the rule

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort uploads after 7 days of inactivity
    }
  }
}

# --- IAM Role for Replication --- #
# This role allows the S3 service to replicate objects from source buckets in the primary region to the destination bucket in the replication region.
resource "aws_iam_role" "replication_role" {
  count = var.enable_s3_replication ? 1 : 0

  name = "${var.name_prefix}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-replication-role"
    Environment = var.environment
  }
}

# --- IAM Policy for Replication --- #
# Grants permissions required for cross-region replication.
# This policy allows the S3 service to:
# - Access source buckets to read objects and their metadata.
# - Write replicated objects to the destination bucket.
resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_s3_replication ? 1 : 0

  name = "${var.name_prefix}-replication-policy"
  role = aws_iam_role.replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ],
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*",
          aws_s3_bucket.wordpress_media.arn,
          "${aws_s3_bucket.wordpress_media.arn}/*",
          aws_s3_bucket.wordpress_scripts.arn,
          "${aws_s3_bucket.wordpress_scripts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = [
          aws_s3_bucket.replication[0].arn,
          "${aws_s3_bucket.replication[0].arn}/*"
        ]
      }
    ]
  })
}

# --- Bucket Policy for Replication Destination --- #
# This policy allows the replication role to write objects into the destination bucket.
resource "aws_s3_bucket_policy" "replication_bucket_policy" {
  count = var.enable_s3_replication ? 1 : 0

  bucket = aws_s3_bucket.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowS3Replication",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.replication_role[0].arn
        },
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = "${aws_s3_bucket.replication[0].arn}/*"
      }
    ]
  })
}

# --- Bucket Policies to Allow Replication --- #
# This policy grants the replication role access to:
# - Read objects and their metadata from source buckets.
# - List bucket contents.
resource "aws_s3_bucket_policy" "source_bucket_replication_policy" {
  for_each = var.enable_s3_replication ? {
    terraform_state   = aws_s3_bucket.terraform_state.id,
    wordpress_media   = aws_s3_bucket.wordpress_media.id,
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
  } : {}

  bucket = each.value

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplication",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.replication_role[0].arn
        },
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:ListBucket"
        ],
        Resource = [
          "${each.value}",
          "${each.value}/*"
        ]
      }
    ]
  })
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
# 5. **Replication Policies**:
#    - IAM Role and Policies: Allow S3 service to replicate objects between buckets.
#    - Destination Bucket Policy: Grants write permissions to the replication role.
#    - Source Bucket Policy: Grants read permissions to the replication role.
#    - These policies ensure secure and efficient cross-region replication.
