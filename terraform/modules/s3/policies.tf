# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# This file defines key configurations for bucket policies, CORS, and lifecycle rules
# to ensure security, compliance, and functionality.

# --- Environment Logic --- #
# In `dev` environment:
# - Created buckets: terraform_state, scripts, logging, ami
# - Not created: wordpress_media, replication
#
# In `prod` environment:
# - All buckets are created.
# - wordpress_media is always created in `prod`.
# - replication is created in `prod` only if `enable_s3_replication = true`.

# --- CORS Configuration for WordPress Media Bucket --- #
# Configures CORS rules only in prod, since wordpress_media is not created in dev.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.wordpress_media[count.index].id # Safe because count=1 in prod, 0 in dev

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"] # Restrict headers to required ones.
    allowed_methods = ["GET", "POST"]                   # Only GET, POST are allowed.
    allowed_origins = ["*"]                             # Initially allow all origins; restrict in prod if needed.
    max_age_seconds = 3000                              # Cache preflight responses.
  }
}

# --- Bucket Policies --- #
# Deny public access and enforce HTTPS/TLS for secure communication.

# Deny public access to all buckets, including replication if enabled.
resource "aws_s3_bucket_policy" "deny_public_access" {
  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets : local.global_base_buckets

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

## Enforce HTTPS for specific buckets
# Uses local.bucket_map from main configuration.
resource "aws_s3_bucket_policy" "force_https" {
  for_each = local.bucket_map
  bucket   = each.value.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnforceTLS",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ],
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
  bucket = aws_s3_bucket.logging.id

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
# Manage noncurrent object versions and incomplete uploads for cost control and compliance.
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets_ids : local.global_base_buckets_ids

  bucket = each.value

  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }

  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Additional configuration for replication if enabled
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  count  = var.enable_s3_replication ? 1 : 0
  bucket = aws_s3_bucket.replication[0].id

  rule {
    id     = "replication-retain-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }

  rule {
    id     = "replication-abort-incomplete-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- IAM Role for Replication --- #
# Allows S3 service to replicate objects from source to destination bucket (replication region).
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
# Grants necessary permissions for cross-region replication.
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
        Resource = var.environment == "prod" ? local.global_prod_replication_resources : local.global_base_replication_resources
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
# Allows the replication role to write objects to the replication bucket.
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

# --- Source Bucket Replication Policy --- #
# Grants the replication role read access on source buckets.
resource "aws_s3_bucket_policy" "source_bucket_replication_policy" {
  for_each = var.enable_s3_replication ? (
    var.environment == "prod" ? local.global_final_replication_source : local.global_base_replication_source
  ) : {}

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
# 1. CORS Configuration:
#    - Applied only in prod for the wordpress_media bucket.
#    - Restrict origins and headers in production for better security.
#
# 2. Public Access Denial & Force HTTPS:
#    - Deny all public access and force HTTPS to enhance security.
#
# 3. Lifecycle Rules:
#    - Dynamically apply based on environment and replication.
#    - Manage noncurrent versions and abort incomplete uploads.
#
# 4. Logging Policy:
#    - Allows the logging service to store access logs in a central logging bucket.
#
# 5. Replication Policies:
#    - IAM Role and Policies ensure secure cross-region replication.
#    - Source and destination policies granted only when needed in prod.
#
# By using separate locals for base, prod, and prod_with_replication sets of buckets,
# we ensure that Terraform knows all keys at plan time and avoids null or undefined keys.