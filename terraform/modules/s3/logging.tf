# --- Logging Configuration --- #
# Enables logging for all S3 buckets except the logging bucket itself to prevent recursive logging.
# Logs are stored in the centralized logging bucket under dedicated prefixes for each source bucket.

# --- Prefixes for Buckets --- #
# Dynamically generate log prefixes for each bucket based on the `buckets` variable.
locals {
  bucket_prefixes = {
    for name, type in var.buckets : name => "${name}/"
  }
}

# --- Logging Configuration for Each Bucket --- #
# Buckets are dynamically selected based on the `buckets` variable from `terraform.tfvars`.
resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = { for key, value in var.buckets : key => value if value && key != "logging" }

  bucket        = each.key
  target_bucket = aws_s3_bucket.buckets["logging"].id
  target_prefix = "${var.name_prefix}/${local.bucket_prefixes[each.key]}"

  depends_on = [aws_s3_bucket.logging]
}

# --- Optional Logging for the Logging Bucket --- #
# Uncomment this block if you need to log activities for the logging bucket itself.
# Ensure that log delivery permissions are properly configured for recursive logs.
# resource "aws_s3_bucket_logging" "logging_for_logging_bucket" {
#   bucket        = aws_s3_bucket.logging.id
#   target_bucket = aws_s3_bucket.logging.id
#   target_prefix = "${var.name_prefix}/${local.bucket_prefixes["logging"]}"
# }

# --- Notes and Best Practices --- #
# 1. **Purpose of Logging**:
#    - Tracks access and operations for debugging, compliance, and audits.
#    - Centralizes logs in a single bucket with organized prefixes for each source.
#
# 2. **Central Logging Bucket**:
#    - Aggregates logs for all buckets except itself (to prevent recursion).
#    - Each bucket's logs are stored under a unique prefix for clarity.
#
# 3. **Dynamic Configuration**:
#    - Automatically applies logging to buckets based on the `buckets` variable.
#    - Uses the `bucket_prefixes` local variable for consistent log organization.
#
# 4. **Optional Logging for Logging Bucket**:
#    - Uncomment the `logging_for_logging_bucket` block if recursive logs are required.
#    - Ensure the logging bucket has appropriate permissions and storage policies.
#
# 5. **Security Considerations**:
#    - Ensure the logging bucket is private and encrypted.
#    - Grant the `s3:PutObject` permission for log delivery.