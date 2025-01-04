# --- Server-Side Encryption for Buckets --- #
# Ensures all buckets use AWS KMS for server-side encryption and enforces object encryption during uploads.

# --- Server-Side Encryption (SSE) Configuration --- #
# Dynamically applies SSE settings to all buckets defined in the `buckets` variable.
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
      sse_algorithm     = "aws:kms"                                                                  # Use AWS KMS for encryption
      kms_master_key_id = var.enable_kms_s3_role ? aws_iam_role.s3_kms_role[0].arn : var.kms_key_arn # KMS key for encrypting data
    }
  }

  lifecycle {
    prevent_destroy = false # Allow smooth updates and replacements
  }
}

# --- Bucket Policy to Enforce Encryption --- #
# Ensures that only encrypted objects can be uploaded to the selected buckets.
resource "aws_s3_bucket_policy" "enforce_encryption" {
  # Apply policy to base and special buckets
  for_each = tomap({
    for key, value in var.buckets : key => value if value == "base" || value == "special"
  })

  # Target bucket
  bucket = aws_s3_bucket.buckets[each.key].id

  # Policy to enforce encryption
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
# 1. **Server-Side Encryption**:
#    - AWS KMS encryption is applied to all objects in S3 buckets using the specified KMS key (`var.kms_key_arn`).
#    - Data at rest is always encrypted to meet security and compliance requirements.
#
# 2. **Bucket Policy for Encryption**:
#    - Only encrypted objects can be uploaded to "base" and "special" buckets.
#    - Prevents accidental or intentional uploads of unencrypted data.
#
# 3. **Lifecycle and Updates**:
#    - `prevent_destroy = false` ensures smooth updates and replacements without requiring manual intervention.
#    - Policies and encryption settings dynamically adapt to changes in the `buckets` variable.
#
# 4. **Security Benefits**:
#    - Protects sensitive data and minimizes the risk of unencrypted data exposure.
#    - Ensures compliance with best practices and organizational policies.
#
# 5. **KMS Key Configuration**:
#    - Verify that the KMS key exists and has permissions for S3 encryption operations.
#    - Review key policies to ensure proper access control.