# --- Versioning Configuration for Buckets --- #
# This file enables versioning for S3 buckets to ensure object history is retained for data recovery or auditing purposes.

# --- Local Variable for Buckets with Versioning --- #
# List of buckets that require versioning.
locals {
  buckets_with_versioning = {
    terraform_state   = aws_s3_bucket.terraform_state.id   # Bucket for Terraform state
    wordpress_media   = aws_s3_bucket.wordpress_media.id   # Bucket for WordPress media files
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id # Bucket for WordPress scripts
    logging           = aws_s3_bucket.logging.id           # Bucket for logging
  }
}

# --- Enable Versioning for Buckets --- #
# Apply versioning settings to all specified buckets.
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = local.buckets_with_versioning # Iterate through each bucket

  bucket = each.value # Target bucket ID

  # Enable versioning to maintain a history of all objects
  versioning_configuration {
    status = "Enabled" # Status of versioning: "Enabled" or "Suspended"
  }

  # Add comments explaining the status options:
  # - "Enabled": Versioning is turned on. All changes to objects will create new versions.
  # - "Suspended": Retains existing versions but stops creating new ones for updates.
}
