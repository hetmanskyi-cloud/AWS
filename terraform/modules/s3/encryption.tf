# --- Server-Side Encryption for Buckets --- #
# This file ensures that all S3 buckets in the project have server-side encryption enabled with AWS KMS.
# Additionally, a bucket policy is applied to enforce encryption during uploads.

# --- Server-Side Encryption Configuration --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  # Loop through buckets based on the environment and replication setting.
  # In `dev`: only base buckets (no wordpress_media, no replication).
  # In `prod`: base buckets plus wordpress_media, and replication if enabled.
  # All these mappings are now defined in s3/main.tf as local.global_* variables.

  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets_ids : local.global_base_buckets_ids

  bucket = each.value # Apply encryption configuration to each bucket

  rule {
    apply_server_side_encryption_by_default {
      # Use AWS KMS for server-side encryption
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
# This policy ensures that only encrypted objects can be uploaded to the selected buckets.
resource "aws_s3_bucket_policy" "enforce_encryption" {
  # Apply the policy to specific buckets
  # local.bucket_map ensures proper inclusion of buckets in the current environment,
  # with correct indexing for resources using `count` (e.g., `wordpress_media`).
  for_each = local.bucket_map # Buckets requiring enforcement

  bucket = each.value.id # Target bucket for the policy

  policy = jsonencode({
    Version = "2012-10-17" # Policy version
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads" # Statement ID for reference
        Effect    = "Deny"                   # Deny action if condition is not met
        Principal = "*"                      # Apply to all users and services
        Action    = "s3:PutObject"           # Action to restrict
        Resource  = "${each.value.arn}/*"    # Target bucket and all objects
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms" # Require KMS encryption
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
#    - If replication is enabled, the replication bucket is also encrypted to ensure data security during cross-region operations.
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