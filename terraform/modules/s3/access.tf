# --- Public Access Block Configuration --- #
# Enforces public access restrictions on specified S3 buckets:
# - Blocks public ACLs and policies.
# - Ignores any existing public ACLs.
# - Restricts bucket-level public access entirely.

# --- Public Access Block Configuration for Buckets --- #
# Dynamically applies public access restrictions to all "base" and "special" buckets as defined in the `buckets` variable.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  # Dynamically process all buckets based on their type
  for_each = tomap({
    for key, value in var.buckets : key => value if value == "base" || value == "special"
  })

  # Target bucket for the public access block
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
# Security Highlights:
# 1. Fully restricts public access to all defined buckets.
# 2. Dynamically identifies "base" and "special" buckets from `buckets` variable.
# 3. Ensures consistent application of best practices across all environments.
# 4. Dynamic logic processes buckets defined in `terraform.tfvars`.