# --- Versioning Configuration for Buckets --- #
# This file enables versioning for S3 buckets to ensure that object history is retained
# for data recovery, auditing, and compliance purposes.

# Instead of defining locals here, we rely on global locals defined in `main.tf`:
# - local.global_base_buckets_ids: Base set of buckets (terraform_state, scripts, logging, ami)
# - local.global_prod_with_replication_buckets_ids: Includes base buckets + wordpress_media in prod,
#   and replication if enabled.
#
# This ensures:
# - In `dev`: versioning is unenabled for all buckets.
# - In `stage`: Only base buckets get versioning.
# - In `prod`: Base buckets + wordpress_media, and replication if enabled, get versioning.

# --- Enable Versioning for Buckets --- #
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets_ids : (var.environment == "stage" ? local.global_base_buckets_ids : {})

  # Each value from the global locals in `main.tf` is a bucket ID string
  bucket = each.value

  versioning_configuration {
    status = "Enabled" # Enable versioning to keep a history of object versions.
  }

  # --- Comments on Status Options --- #
  # - "Enabled": Versioning is turned on. Changes to objects create new versions.
  # - "Suspended": Retains existing versions but stops creating new ones.
}

# --- Notes --- #
# 1. Purpose of Versioning:
#    - Ensures historical versions of objects are retained.
#    - Useful for data recovery, audits, and compliance.
#
# 2. Integration with Environment Logic:
#    - In `dev`: Only base buckets are versioned (no wordpress_media, no replication).
#    - In `prod`: wordpress_media is included, and replication is versioned if enabled.
#
# 3. Best Practices:
#    - Enable versioning on critical buckets.
#    - Use lifecycle rules to manage storage costs for older versions.
#
# By centralizing environment logic in `main.tf`, we avoid duplicating conditions here
# and ensure consistent handling of all buckets across environments.