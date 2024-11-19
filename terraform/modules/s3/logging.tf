# --- Logging Configuration for Buckets --- #

# Define a local variable with bucket configurations for logging
locals {
  # Buckets that require logging and their respective prefixes
  buckets_with_logging = {
    terraform_state   = { bucket_id = aws_s3_bucket.terraform_state.id, prefix = "terraform_state/" }
    wordpress_media   = { bucket_id = aws_s3_bucket.wordpress_media.id, prefix = "wordpress_media/" }
    wordpress_scripts = { bucket_id = aws_s3_bucket.wordpress_scripts.id, prefix = "wordpress_scripts/" }
    # Uncomment if the logging bucket itself requires logging
    # logging           = { bucket_id = aws_s3_bucket.logging.id, prefix = "logging/" }
  }
}

# Create logging configuration for each bucket
resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = local.buckets_with_logging

  bucket        = each.value.bucket_id                      # Target bucket for logging
  target_bucket = aws_s3_bucket.logging.id                  # Bucket where logs will be stored
  target_prefix = "${var.name_prefix}/${each.value.prefix}" # Prefix for log files
}
