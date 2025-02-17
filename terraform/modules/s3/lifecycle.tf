# --- Lifecycle Policies for S3 Buckets --- #
# Defines lifecycle rules for cost optimization and data management.

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  # Rule to manage noncurrent object versions for cost control.
  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Set in terraform.tfvars
    }
  }

  # Rule to automatically abort incomplete multipart uploads.
  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Additional rule for 'scripts' bucket to delete old versions only
  dynamic "rule" {
    for_each = each.key == "scripts" ? [1] : []

    content {
      id     = "scripts-delete-old-versions"
      status = "Enabled"

      noncurrent_version_expiration {
        noncurrent_days = 30 # Delete old versions after 30 days
      }
    }
  }

  # Additional rule for 'logging' bucket to delete old logs
  dynamic "rule" {
    for_each = each.key == "logging" ? [1] : []

    content {
      id     = "delete-old-logs"
      status = "Enabled"

      expiration {
        days = 30 # Delete logs after 30 days
      }
    }
  }
}

# --- Replication Bucket Lifecycle Rules --- #
# Defines lifecycle rules for the replication bucket.
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? 1 : 0

  bucket = aws_s3_bucket.buckets["replication"].id

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
# 1. Lifecycle Management:
#    - Manages object lifecycles for cost optimization.
#    - Retains noncurrent versions.
#    - Aborts incomplete uploads.
#    - Consider additional rules for temporary files in production.
# 2. Replication Lifecycle:
#    - Configures lifecycle rules for the replication bucket.
#    - Created only if replication is enabled.