# --- Server-Side Encryption for Buckets --- #

# Server-Side Encryption Configuration for Buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  for_each = {
    terraform_state   = aws_s3_bucket.terraform_state.id
    wordpress_media   = aws_s3_bucket.wordpress_media.id
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id
    logging           = aws_s3_bucket.logging.id
  }

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
