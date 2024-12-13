# --- Logging Configuration for Buckets --- #
# This file configures S3 bucket logging to enhance observability and security.
# Logs from each bucket are stored in a central logging bucket, organized by prefixes for clarity.

# --- Prefixes for Buckets --- #
# This static map associates each bucket key with a logging prefix.
# These prefixes help categorize logs within the central logging bucket.
locals {
  bucket_prefixes = {
    terraform_state = "terraform_state/"
    wordpress_media = "wordpress_media/"
    scripts         = "scripts/"
    ami             = "ami/"
    replication     = "replication/"
    logging         = "logging/" # If you decide to enable logging for the logging bucket itself.
  }
}

# Uncomment the following resource if you wish to enable logging for the logging bucket itself.
# Note: To make this functional, ensure the logging bucket is included in the appropriate global locals in main.tf.
#
# resource "aws_s3_bucket_logging" "logging_for_logging_bucket" {
#   bucket        = aws_s3_bucket.logging.id
#   target_bucket = aws_s3_bucket.logging.id
#   target_prefix = "${var.name_prefix}/${local.bucket_prefixes["logging"]}"
# }

# --- Logging Configuration for Each Bucket --- #
# We rely on global locals defined in main.tf (`global_base_buckets_ids`, `global_prod_with_replication_buckets_ids`)
# to determine which buckets exist in each environment and whether replication is enabled.
#
# In `dev`: only base buckets (terraform_state, scripts, logging, ami)
# In `prod`: base buckets plus wordpress_media, and replication if enabled
resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets_ids : local.global_base_buckets_ids

  # Each value is a bucket ID string from main.tf
  bucket = each.value

  # All logs are stored in the central logging bucket
  target_bucket = aws_s3_bucket.logging.id
  # Use the bucket key to determine the prefix for organizing logs
  target_prefix = "${var.name_prefix}/${lookup(local.bucket_prefixes, each.key, "unknown/")}"
}

# --- Notes and Best Practices --- #
# 1. Purpose of Logging:
#    - Enables tracking of access and operations on S3 buckets.
#    - Useful for debugging, compliance, and security audits.
#
# 2. Central Logging Bucket:
#    - All logs are aggregated into one bucket.
#    - The prefix structure (`terraform_state/`, `scripts/`, etc.) helps identify logs easily.
#
# 3. Environment-Specific Logic:
#    - In `dev`, you get only the base set of buckets logged.
#    - In `prod`, you also get wordpress_media, and replication if enabled.
#
# 4. Replication Logging:
#    - If replication is enabled (in `prod`), logs for that bucket are prefixed with `replication/`.
#
# 5. Security Considerations:
#    - Ensure the logging bucket is private and encrypted.
#    - Grant the necessary permissions (`s3:PutObject`) to allow log delivery.
#
# 6. Performance:
#    - Logging adds minor overhead but is essential for monitoring and troubleshooting.
#
# 7. Customization:
#    - Adjust `bucket_prefixes` if you change bucket names or need different prefixes.
#    - Uncomment the `logging_for_logging_bucket` resource if you need to log the logging bucket itself, and update main.tf accordingly.
