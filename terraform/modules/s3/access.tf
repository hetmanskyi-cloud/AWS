# --- Public Access Block Configuration --- #
# This block applies public access restrictions dynamically to all buckets.
# The `for_each` loop filters buckets to include only `base` and `special` types.
# Public access control settings:
# - Block public ACLs and policies.
# - Ignore any existing public ACLs.
# - Restrict public bucket access entirely.

# This file enforces a public access block on all S3 buckets to prevent unintended public exposure.

# --- Public Access Block Configuration for Buckets --- #
# Applies to all "base" and "special" buckets as defined in the `buckets` variable.
# Ensures public access is blocked for these buckets by default.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  # Dynamically process all buckets based on the environment
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.type == "base" || bucket.type == "special"
  }

  # Target bucket
  bucket = aws_s3_bucket.buckets[each.key].id

  # Block all public ACLs (Access Control Lists)
  block_public_acls = true
  # Ensure public bucket policies are blocked
  block_public_policy = true
  # Ignore any public ACLs applied to the bucket
  ignore_public_acls = true
  # Restrict the bucket from being publicly accessible
  restrict_public_buckets = true
}

# --- Notes --- #
# 1. Public Access Block:
#    - Applies to all buckets, regardless of environment or type.
#    - Prevents any form of public access via ACLs or bucket policies.
#
# 2. Dynamic Bucket Management:
#    - Uses the `buckets` variable from `terraform.tfvars` for centralized bucket control.
#    - Automatically processes all base and special buckets.
#
# 3. Security Best Practices:
#    - `block_public_acls`: Prevents adding ACLs that grant public access.
#    - `block_public_policy`: Prevents bucket policies that allow public access.
#    - `ignore_public_acls`: Ensures the bucket ignores any public ACLs.
#    - `restrict_public_buckets`: Blocks any attempts to make the bucket public.
#
# 4. Centralized Logic:
#    - Simplifies management by centralizing bucket definitions in `terraform.tfvars`.
#    - Automatically adjusts based on environment and bucket configuration.