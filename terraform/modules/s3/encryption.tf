# --- Server-Side Encryption for Buckets --- #
# This file ensures that all S3 buckets in the project have server-side encryption enabled with AWS KMS.
# Additionally, a bucket policy is applied to enforce encryption during uploads.

# --- Server-Side Encryption (SSE) Configuration --- #
# Dynamically applies SSE settings to all buckets defined in the `buckets` variable.
# Ensures:
# - AWS KMS is used for encryption.
# - All objects are encrypted at rest.
# - A bucket policy enforces encryption during uploads.
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  # Loop through all buckets defined in the `buckets` variable.
  for_each = {
    for bucket in var.buckets : bucket.name => bucket
  }

  bucket = aws_s3_bucket.buckets[each.key].id # Apply encryption configuration to each bucket

  rule {
    apply_server_side_encryption_by_default {
      # The ARN of the KMS key must be pre-created or provided by another module.
      # This ensures server-side encryption for all objects in the bucket.
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn # Use the KMS key passed as a variable
    }
  }

  lifecycle {
    # Allow buckets to be updated or replaced without errors
    prevent_destroy = false
  }
}

# --- Bucket Policy to Enforce Encryption --- #
# Ensures that only encrypted objects can be uploaded to the selected buckets.
resource "aws_s3_bucket_policy" "enforce_encryption" {
  # Apply the policy to all buckets requiring encryption enforcement
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.type == "base" || bucket.type == "special"
  }

  bucket = aws_s3_bucket.buckets[each.key].id # Target bucket for the policy

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*",
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# --- Notes and Best Practices --- #
# 1. **Server-Side Encryption Configuration**:
#    - Ensures all objects stored in the bucket are encrypted with AWS KMS.
#    - Uses the KMS key specified by the `var.kms_key_arn` variable.
#    - Applies to all buckets defined in the `buckets` variable.
#
# 2. **Bucket Policy to Enforce Encryption**:
#    - The policy denies uploads of unencrypted objects.
#    - Users and services must explicitly specify encryption using AWS KMS during uploads.
#
# 3. **Lifecycle Settings**:
#    - `prevent_destroy = false` allows buckets to be updated or replaced without requiring manual deletion.
#
# 4. **Why This Matters**:
#    - Enforcing encryption ensures compliance with security best practices and protects sensitive data.
#    - Unencrypted uploads are automatically rejected, reducing the risk of data exposure.