# --- Server-Side Encryption for Buckets --- #
# This file ensures that all S3 buckets in the project have server-side encryption (SSE) enabled using AWS KMS.
# Additionally, bucket policies are applied to enforce encryption during object uploads.

# --- Server-Side Encryption (SSE) Configuration --- #
# Dynamically applies SSE settings to all buckets defined in the `buckets` variable.
# Ensures:
# - AWS KMS is used for encryption.
# - All objects are encrypted at rest with the specified KMS key.
# - A bucket policy enforces encryption during uploads.

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  # Apply encryption settings to all defined buckets
  for_each = tomap({
    for key, value in var.buckets : key => value
  })

  # Target bucket
  bucket = aws_s3_bucket.buckets[each.key].id

  # Server-Side Encryption Configuration
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"       # Use AWS KMS for encryption
      kms_master_key_id = var.kms_key_arn # KMS key specified via variable
    }
  }

  lifecycle {
    prevent_destroy = false # Allow updates or replacements without requiring manual intervention
  }

  # --- Notes --- #
  # 1. Applies encryption settings dynamically to all buckets defined in the `buckets` variable.
  # 2. Uses the KMS key specified in `var.kms_key_arn` to encrypt objects.
  # 3. Prevents destruction errors by allowing updates and replacements.
}

# --- Bucket Policy to Enforce Encryption --- #
# Ensures that only encrypted objects can be uploaded to the selected buckets.
resource "aws_s3_bucket_policy" "enforce_encryption" {
  # Apply the encryption enforcement policy to base and special buckets
  for_each = tomap({
    for key, value in var.buckets : key => value if value == "base" || value == "special"
  })

  # Target bucket
  bucket = aws_s3_bucket.buckets[each.key].id

  # Bucket policy to enforce encryption
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

  # --- Notes --- #
  # 1. Denies uploads of unencrypted objects to ensure compliance with security requirements.
  # 2. Applies only to base and special buckets to align with project requirements.
}

# --- Notes and Best Practices --- #
# 1. **Server-Side Encryption**:
#    - Applies AWS KMS encryption to all objects stored in the bucket.
#    - Ensures data at rest is always encrypted with the specified KMS key.
#
# 2. **Bucket Policy to Enforce Encryption**:
#    - Prevents accidental or intentional uploads of unencrypted objects.
#    - Users and services must explicitly specify encryption during uploads.
#
# 3. **Lifecycle Settings**:
#    - `prevent_destroy = false` ensures smooth updates and replacements.
#    - Prevents manual intervention during bucket changes.
#
# 4. **Dynamic Configuration**:
#    - Uses the `buckets` variable to apply encryption settings across all relevant buckets.
#    - Adapts to changes in bucket definitions dynamically.
#
# 5. **Security Benefits**:
#    - Protects sensitive data by enforcing encryption at rest.
#    - Reduces risk of accidental exposure of unencrypted data.
#
# 6. **KMS Key Configuration**:
#    - Ensure that the KMS key specified in `var.kms_key_arn` exists and has the necessary permissions.
#    - Review and manage key policies to allow appropriate access for S3 encryption operations.