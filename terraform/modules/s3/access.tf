# --- Public Access Block Configuration --- #
# This file enforces public access restrictions on S3 buckets dynamically, ensuring no unintended public exposure.
# Public access control settings:
# - Block public ACLs and policies.
# - Ignore any existing public ACLs.
# - Restrict public bucket access entirely.

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

  # --- Notes for Public Access Configuration --- #
  # 1. Public access is fully restricted for all buckets.
  # 2. Applies to both base and special buckets, ensuring consistent security.
  # 3. Dynamic logic processes buckets defined in `terraform.tfvars`.
}

# --- Notes --- #
# 1. **Public Access Block**:
#    - Ensures no public access is allowed to any S3 bucket.
#    - Prevents potential security risks associated with misconfigured ACLs or policies.
#
# 2. **Dynamic Bucket Management**:
#    - Uses the `buckets` variable to dynamically identify relevant buckets.
#    - Processes all base and special buckets for consistent application of security settings.
#
# 3. **Security Best Practices**:
#    - `block_public_acls`: Prevents adding ACLs that grant public access.
#    - `block_public_policy`: Blocks bucket policies that allow public access.
#    - `ignore_public_acls`: Ignores any public ACLs that might be applied.
#    - `restrict_public_buckets`: Fully restricts public access at the bucket level.
#
# 4. **Integration with Other Resources**:
#    - Works seamlessly with the main S3 module configuration.
#    - Ensures public access block settings are applied uniformly across environments and bucket types.