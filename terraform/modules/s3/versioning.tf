# --- Versioning Configuration for Buckets --- #
# This file dynamically enables versioning for S3 buckets based on the `buckets` variable.
# Retains object history for recovery, compliance, and auditing.

# --- Enable Versioning for Buckets --- #
resource "aws_s3_bucket_versioning" "versioning" {
  # Enable versioning only for buckets explicitly marked in `buckets` and `enable_versioning`.
  for_each = {
    for key, value in var.enable_versioning : key => value
    if lookup(var.buckets, key, false) && value == true
  }

  # Reference the bucket for which versioning is being applied.
  bucket = aws_s3_bucket.buckets[each.key].id

  # Configure versioning to retain object history.
  versioning_configuration {
    status = "Enabled" # Versioning is enabled to retain object history.
  }
}

# --- Notes --- #
# 1. **Purpose of Versioning**:
#    - Ensures historical object retention for recovery, auditing, and compliance.
#    - Protects against accidental deletions or overwrites.
#
# 2. **Versioning Logic**:
#    - Controlled by the `enable_versioning` variable in `terraform.tfvars`.
#    - If a bucket is not listed in `enable_versioning` or set to `false`, versioning is not applied.
#
# 3. **Best Practices**:
#    - Enable versioning on critical buckets, especially in production environments.
#    - Pair versioning with lifecycle rules to transition or expire noncurrent versions and manage costs.
#
# 4. **Dynamic Application**:
#    - Versioning logic applies dynamically based on the `buckets` and `enable_versioning` variables.
#    - Simplifies environment management by centralizing control over versioning settings.
#
# 5. **Integration**:
#    - Works seamlessly with the main S3 module configuration.
#    - Ensure the `enable_versioning` map in `terraform.tfvars` includes all relevant buckets.
#
# 6. **Important Considerations**:
#    - Versioning can be enabled for existing buckets at any time without requiring bucket recreation.
#    - Objects added before enabling versioning are marked with a "null version" and remain unchanged.