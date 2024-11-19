# --- Versioning Configuration for Buckets --- #

# Define a local variable with all buckets that require versioning
locals {
  buckets_with_versioning = {
    terraform_state   = aws_s3_bucket.terraform_state.id
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    logging           = aws_s3_bucket.logging.id
  }
}

# Enable versioning for all buckets listed in the local variable
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = local.buckets_with_versioning

  bucket = each.value
  versioning_configuration {
    status = "Enabled" # Enable versioning to maintain the history of objects
  }
}

