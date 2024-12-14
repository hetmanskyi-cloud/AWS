# --- Logging Configuration --- #
# Enables logging for all buckets except the logging bucket itself (to prevent recursive logs).
# Logs are stored in the logging bucket with prefixes for source buckets.
# The `for_each` loop uses the `buckets` variable to dynamically identify logging targets.

# --- Prefixes for Buckets --- #
# Dynamically determine prefixes for each bucket based on the `buckets` variable.
locals {
  bucket_prefixes = {
    for bucket in var.buckets : bucket.name => "${bucket.name}/"
  }
}

# --- Logging Configuration for Each Bucket --- #
# Configures logging for all buckets except the logging bucket itself.
# The logging bucket does not log itself to avoid recursive dependencies.
# Logs from all other buckets are sent to this centralized logging bucket.
resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = {
    for bucket in var.buckets : bucket.name => bucket
    if bucket.name != "logging" # Exclude the logging bucket itself to avoid recursive logs
  }

  bucket        = aws_s3_bucket.buckets[each.key].id
  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "${var.name_prefix}/${lookup(local.bucket_prefixes, each.key, "unknown/")}"
}

# --- Optional Logging for the Logging Bucket --- #
# Uncomment this block to enable logging for the logging bucket itself.
# Note: Ensure the logging bucket is properly configured to store its own logs.
# resource "aws_s3_bucket_logging" "logging_for_logging_bucket" {
#   bucket        = aws_s3_bucket.logging.id
#   target_bucket = aws_s3_bucket.logging.id
#   target_prefix = "${var.name_prefix}/${local.bucket_prefixes["logging"]}"
# }

# --- Notes and Best Practices --- #
# 1. Purpose of Logging:
#    - Enables tracking of access and operations on S3 buckets.
#    - Useful for debugging, compliance, and security audits.
#
# 2. Central Logging Bucket:
#    - Aggregates logs for all buckets into a single location.
#    - Each bucket's logs are organized under a dedicated prefix (e.g., `terraform_state/`, `scripts/`).
#
# 3. Dynamic Configuration:
#    - Uses the `buckets` variable to dynamically determine which buckets require logging.
#    - The `bucket_prefixes` local maps bucket names to their respective log prefixes.
#
# 4. Environment-Specific Logic:
#    - Logging applies to all buckets defined in the `buckets` variable for the current environment.
#    - The logging bucket itself can optionally have logging enabled (commented out by default).
#
# 5. Security Considerations:
#    - Ensure the logging bucket is private and encrypted.
#    - Grant the `s3:PutObject` permission to allow log delivery.
#
# 6. Customization:
#    - Adjust `bucket_prefixes` in `buckets` if bucket names or prefixes change.
#    - Uncomment the `logging_for_logging_bucket` resource if logging for the logging bucket is needed.