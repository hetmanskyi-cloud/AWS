# --- Versioning Configuration for Buckets --- #
# This file enables versioning for S3 buckets to ensure object history is retained
# for data recovery, auditing, and compliance purposes.

# --- Enable Versioning for Buckets --- #
# Applies versioning dynamically based on the bucket type and environment:
# - In `dev`: Versioning is disabled for cost efficiency.
# - In `stage`: Enabled for base buckets to ensure stability.
# - In `prod`: Fully enabled for both base and special buckets.
# The `for_each` loop filters buckets based on their type and environment logic.

resource "aws_s3_bucket_versioning" "versioning" {
  # Dynamically enable versioning for buckets based on environment logic.
  for_each = var.environment == "prod" ? {
    for bucket in var.buckets : bucket.name => bucket if bucket.type == "base" || bucket.type == "special"
    } : (
    var.environment == "stage" ? {
      for bucket in var.buckets : bucket.name => bucket if bucket.type == "base"
    } : {}
  )

  # Apply versioning to each bucket.
  bucket = aws_s3_bucket.buckets[each.key].id

  # Enables versioning for buckets to retain object history.
  # Versioning status is set dynamically based on the environment:
  # - "Enabled" in `stage` and `prod` for all relevant buckets.
  # - "Disabled" in `dev` to minimize costs.
  versioning_configuration {
    status = "Enabled" # Enable versioning to retain object history.
  }

  # --- Comments on Status Options --- #
  # - "Enabled": Versioning is active, creating new versions on changes.
  # - "Suspended": Retains existing versions but stops creating new ones.
}

# --- Notes --- #
# 1. Purpose of Versioning:
#    - Enables historical version retention for recovery, audits, and compliance.
#    - Provides a safeguard against accidental deletions or overwrites.
#
# 2. Environment Logic:
#    - In `dev`: Versioning is disabled to reduce costs.
#    - In `stage`: Versioning is enabled for base buckets to test functionality and ensure stability.
#    - In `prod`: Full versioning is enabled for base and special buckets for maximum durability.
#
# 3. Best Practices:
#    - Always enable versioning on critical buckets, especially in `prod`.
#    - Pair versioning with lifecycle rules to control costs by managing older versions.
#
# 4. Centralized Logic:
#    - The logic dynamically applies versioning based on the `buckets` variable from `terraform.tfvars`.
#    - This approach ensures consistency across environments and minimizes manual intervention.