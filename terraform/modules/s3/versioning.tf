# --- Versioning Configuration for Buckets --- #
# This file dynamically enables versioning for S3 buckets based on environment and
# the `enable_versioning` variable. Retains object history for recovery, compliance, and auditing.

# --- Enable Versioning for Buckets --- #
resource "aws_s3_bucket_versioning" "versioning" {
  # Dynamically enable versioning for buckets explicitly marked in `enable_versioning`.
  for_each = tomap({
    for key, value in var.buckets : key => value if lookup(var.enable_versioning, key, false)
  })

  # Reference the bucket for which versioning is being applied.
  bucket = aws_s3_bucket.buckets[each.key].id

  # Configure versioning to retain object history.
  versioning_configuration {
    status = "Enabled" # Versioning is enabled to retain object history.
  }

  # --- Notes on Versioning Configuration --- #
  # 1. "Enabled": New versions are created on changes.
  # 2. "Suspended": Retains existing versions but stops creating new ones.
  #    (Suspension can be configured manually if required.)
}

# --- Notes --- #
# 1. **Purpose of Versioning**:
#    - Ensures historical object retention for recovery, auditing, and compliance.
#    - Protects against accidental deletions or overwrites.
#
# 2. **Versioning Logic**:
#    - Controlled by the `enable_versioning` variable in `dev.tfvars`.
#    - If `enable_versioning` is not set for a bucket or explicitly false, no versioning is applied.
#
# 3. **Best Practices**:
#    - Enable versioning on critical buckets, especially in production.
#    - Pair versioning with lifecycle rules to transition or expire noncurrent versions and manage costs.
#
# 4. **Enable Versioning Anytime**:
#    - Versioning can be enabled for existing buckets at any time without requiring bucket recreation.
#    - Objects added before enabling versioning are marked with a "null version" and remain unchanged.
#
# 5. **Dynamic Application**:
#    - Versioning logic applies dynamically to buckets based on the `buckets` and `enable_versioning` variables.
#    - Simplifies environment management by centralizing control over versioning settings.
#
# 6. **Integration**:
#    - Works seamlessly with the main S3 module configuration.
#    - Ensure the `enable_versioning` map in `dev.tfvars` includes all relevant buckets.