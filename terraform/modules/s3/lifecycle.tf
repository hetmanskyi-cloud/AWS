# --- Default Region Bucket Lifecycle --- #
# Defines lifecycle rules for default region S3 buckets.
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  # Dynamic lifecycle for default region buckets
  for_each = { for key, value in var.default_region_buckets : key => value if value.enabled }

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  # Rule: Delete objects after 1 day (TEST ENV ONLY!)
  rule {
    id     = "${each.key}-delete-objects" # Rule ID: delete-objects
    status = "Enabled"                    # Rule status: Enabled

    expiration {
      days = 1 # Expiration: 1 day (TEST ENV!)
    }
  }

  # Rule: Retain noncurrent versions
  rule {
    id     = "${each.key}-retain-versions" # Rule ID: retain-versions
    status = "Enabled"                     # Rule status: Enabled

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Noncurrent days (var)
    }
  }

  # Rule: Abort incomplete uploads
  rule {
    id     = "${each.key}-abort-incomplete-uploads" # Rule ID: abort-incomplete-uploads
    status = "Enabled"                              # Rule status: Enabled

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort after 7 days
    }
  }
}

# --- Replication Region Bucket Lifecycle --- #
# Defines lifecycle rules for replication region buckets.
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  # Dynamic lifecycle for replication region buckets
  for_each = { for key, value in var.replication_region_buckets : key => value if value.enabled }

  provider = aws.replication                                  # Use replication provider for replication buckets
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target replication bucket

  # Rule: Delete objects after 1 day (TEST ENV ONLY!)
  rule {
    id     = "replication-delete-objects"
    status = "Enabled"

    expiration {
      days = 1 # Expiration: 1 day (TEST ENV!)
    }
  }

  # Rule: Retain noncurrent versions (replication)
  rule {
    id     = "replication-retain-versions" # Rule ID: replication-retain-versions
    status = "Enabled"                     # Rule status: Enabled

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Noncurrent days (var)
    }
  }

  # Rule: Abort incomplete uploads (replication)
  rule {
    id     = "replication-abort-incomplete-uploads" # Rule ID: replication-abort-incomplete-uploads
    status = "Enabled"                              # Rule status: Enabled

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort after 7 days
    }
  }
}

# --- Module Notes --- #
# General notes for S3 lifecycle configuration.

# 1. Default Region Lifecycle:
#   - Cost optimization via lifecycle rules.
#   - Includes version retention & abort incomplete uploads.
#   - **`delete-objects` rule (days=1) - TEST ENV ONLY!  PRODUCTION: REMOVE or set days > 30 to avoid data loss!**

# 2. Replication Lifecycle:
#   - Separate lifecycle config for replication buckets.
#   - Dynamic via `for_each`.
#   - Version retention & abort incomplete uploads rules.
#   - `abort_incomplete_multipart_upload` days (7) unified with default buckets.