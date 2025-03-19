# --- Default Region Bucket Lifecycle --- #
# Defines lifecycle rules for default region S3 buckets.
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  # Dynamic lifecycle for default region buckets
  for_each = { for key, value in var.default_region_buckets : key => value if value.enabled && key != "terraform_state" }

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  # Rule: Delete objects after 1 day (TEST ENV ONLY!)
  rule {
    id     = "${each.key}-delete-objects" # Rule ID: delete-objects
    status = "Enabled"                    # Rule status: Enabled

    filter {
      prefix = "" # Empty prefix matches all objects
    }

    expiration {
      days = 1 # Expiration: 1 day (TEST ENV!)
    }
  }

  # Rule: Retain noncurrent versions
  rule {
    id     = "${each.key}-retain-versions" # Rule ID: retain-versions
    status = "Enabled"                     # Rule status: Enabled

    filter {
      prefix = "" # Apply to all objects
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Noncurrent days (var)
    }
  }

  # Rule: Abort incomplete uploads
  rule {
    id     = "${each.key}-abort-incomplete-uploads" # Rule ID: abort-incomplete-uploads
    status = "Enabled"                              # Rule status: Enabled

    filter {
      prefix = "" # Apply to all objects
    }

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

    filter {
      prefix = "" # Apply to all objects
    }

    expiration {
      days = 1 # Expiration: 1 day (TEST ENV!)
    }
  }

  # Rule: Retain noncurrent versions (replication)
  rule {
    id     = "replication-retain-versions" # Rule ID: replication-retain-versions
    status = "Enabled"                     # Rule status: Enabled

    filter {
      prefix = "" # Apply to all objects
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Noncurrent days (var)
    }
  }

  # Rule: Abort incomplete uploads (replication)
  rule {
    id     = "replication-abort-incomplete-uploads" # Rule ID: replication-abort-incomplete-uploads
    status = "Enabled"                              # Rule status: Enabled

    filter {
      prefix = "" # Apply to all objects
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort after 7 days
    }
  }
}

# --- Lifecycle Policy for terraform_state Bucket --- #
# Defines lifecycle rules for terraform_state bucket.
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_lifecycle" {
  # Apply only if terraform_state bucket is enabled
  for_each = { for key, value in var.default_region_buckets : key => value if value.enabled && key == "terraform_state" }

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  # Rule: Retain all object versions for 90 days (no deletion)
  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    filter {
      prefix = "" # Apply to all objects
    }

    noncurrent_version_expiration {
      noncurrent_days = 90 # Keep noncurrent versions for 90 days
    }
  }

  # Rule: Automatically abort incomplete multipart uploads after 7 days
  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = "" # Apply to all objects
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort uploads after 7 days
    }
  }
}

# --- Module Notes --- #
# General notes for S3 lifecycle configuration.

# 1. Default Region Lifecycle:
#   - Cost optimization via lifecycle rules.
#   - Includes version retention & abort incomplete uploads.
#   - **`delete-objects` rule (days=1) applies ONLY to test environments.**
#   - Production environments should **remove this rule** or **increase retention to 30+ days**.

# 2. Replication Lifecycle:
#   - Separate lifecycle configuration for replication buckets.
#   - Dynamically applied via `for_each` to all enabled replication buckets.
#   - Includes version retention & abort incomplete uploads rules.
#   - `abort_incomplete_multipart_upload` is set to 7 days, consistent with default buckets.

# 3. Terraform State Lifecycle:
#   - Managed separately to prevent accidental state file deletion.
#   - **No automatic deletion of objects.** All object versions are retained for 90 days.
#   - Incomplete multipart uploads are aborted after 7 days to save storage costs.
#   - Lifecycle applies **only if `terraform_state` bucket is enabled.**