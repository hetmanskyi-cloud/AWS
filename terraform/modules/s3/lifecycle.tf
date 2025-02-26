# --- Lifecycle Policies for S3 Buckets --- #

# Defines lifecycle rules for cost optimization and data management S3 buckets in the default region.
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = {
    for key, value in var.default_region_buckets : key => value
    if value.enabled
  }

  bucket = aws_s3_bucket.default_region_buckets[each.key].id

  # Delete all objects after 1 day (to allow Terraform to destroy the bucket)
  rule {
    id     = "${each.key}-delete-objects"
    status = "Enabled"

    expiration {
      days = 1 # Remove all objects after 1 day
    }
  }

  # Manage noncurrent object versions (default retention: 30 days)
  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Defined in terraform.tfvars
    }
  }

  # Abort incomplete multipart uploads after 7 days
  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Cleanup incomplete uploads
    }
  }
}

# --- Replication Bucket Lifecycle Rules --- #
# Defines lifecycle rules for the replication buckets.
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  for_each = {
    for key, value in var.replication_region_buckets : key => value
    if value.enabled
  }

  bucket = aws_s3_bucket.s3_replication_bucket[each.key].id

  # Retain noncurrent object versions for a defined period
  rule {
    id     = "replication-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Set in terraform.tfvars
    }
  }

  # Automatically abort incomplete multipart uploads after 7 days
  rule {
    id     = "replication-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Notes --- #
# 1. Lifecycle Management (Default Region Buckets):
#     - Optimizes S3 costs via object lifecycle rules.
#     - Includes rules for version retention and aborting incomplete uploads.
#     - **`delete-objects` rule (days=1) is optimized for TEST environments to speed up `terraform destroy`.**
#       **For PRODUCTION, REMOVE this rule or set `days` to a much higher value (e.g., 30+ days)**
#       **to prevent accidental data loss. This rule will permanently delete ALL objects after just 1 day!**
#
# 2. Replication Bucket Lifecycle:
#     - Configures lifecycle rules for replication buckets (separate resource).
#     - Dynamically applied via `for_each` to enabled replication buckets.
#     - Includes version retention and incomplete upload abortion rules.
#     - **`abort_incomplete_multipart_upload` days are unified (7 days) with default buckets for consistency.**