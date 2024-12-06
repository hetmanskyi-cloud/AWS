# --- Logging Configuration for Buckets --- #
# This file sets up logging for S3 buckets to enhance observability and security.
# Logs for each bucket are stored in a dedicated logging bucket, with structured prefixes for clarity.

# --- Define Local Variables for Logging --- #
locals {
  # List of buckets that require logging and their respective prefixes
  buckets_with_logging = {
    terraform_state   = { bucket_id = aws_s3_bucket.terraform_state.id, prefix = "terraform_state/" }     # Logs for Terraform state bucket
    wordpress_media   = { bucket_id = aws_s3_bucket.wordpress_media.id, prefix = "wordpress_media/" }     # Logs for WordPress media bucket
    wordpress_scripts = { bucket_id = aws_s3_bucket.wordpress_scripts.id, prefix = "wordpress_scripts/" } # Logs for WordPress scripts bucket

    # Uncomment the line below if logging is required for the logging bucket itself
    # logging = { bucket_id = aws_s3_bucket.logging.id, prefix = "logging/" } 
  }
}

# --- Logging Configuration for Each Bucket --- #
resource "aws_s3_bucket_logging" "bucket_logging" {
  # Loop through each bucket that requires logging
  for_each = local.buckets_with_logging

  # The bucket to which logging is applied
  bucket = each.value.bucket_id

  # Specify the logging bucket and prefix for log files
  target_bucket = aws_s3_bucket.logging.id                  # Central logging bucket
  target_prefix = "${var.name_prefix}/${each.value.prefix}" # Prefix for log files, categorized by bucket
}

# --- Notes and Best Practices --- #
# 1. **Purpose of Logging**:
#    - Enables tracking of access and operations on S3 buckets.
#    - Useful for debugging, compliance, and security audits.
#
# 2. **Logging Bucket**:
#    - All logs are stored in a central "logging" bucket.
#    - The `target_prefix` organizes logs by source bucket for easy identification.
#
# 3. **Customizing Logging**:
#    - To enable logging for the logging bucket itself, uncomment the corresponding line in `buckets_with_logging`.
#    - Ensure that the logging bucket has sufficient permissions to store logs.
#
# 4. **Security Considerations**:
#    - Ensure the logging bucket is private and encrypted to protect sensitive log data.
#    - Use `s3:PutObject` permissions in the logging bucket's policy to allow log delivery from other buckets.
#
# 5. **Performance Impact**:
#    - Logging adds a minor overhead but is essential for monitoring and troubleshooting.
#
# 6. **Prefix Structure**:
#    - Organized by bucket names (e.g., `terraform_state/`), ensuring clear categorization.
#
# 7. **Why Use Locals**:
#    - The `locals` block simplifies the code by centralizing bucket configurations.
