# --- Public Access Block for Buckets --- #

# Define a local variable with all buckets requiring public access block
locals {
  buckets_with_public_access_block = {
    terraform_state   = aws_s3_bucket.terraform_state.id
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    logging           = aws_s3_bucket.logging.id
  }
}

# Apply public access block to all buckets
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  for_each = local.buckets_with_public_access_block

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
