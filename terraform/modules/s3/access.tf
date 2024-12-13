# --- Public Access Block Configuration for S3 Buckets --- #
# This file enforces a public access block on all S3 buckets to prevent unintended public exposure.

# --- Notes on Environment Logic --- #
# In `dev` environment:
# - Buckets: terraform_state, scripts, logging, ami
# - No wordpress_media, no replication
#
# In `prod` environment:
# - All buckets are created.
# - wordpress_media is always created in prod.
# - replication is created only if enable_s3_replication = true.

# --- Public Access Block Resource --- #
# Dynamically applies a public access block to buckets based on the environment and replication setting.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  # Determine for_each based on environment and replication
  for_each = var.environment == "prod" ? local.global_prod_with_replication_buckets : local.global_base_buckets

  # Target bucket
  bucket = each.value.id

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
# block_public_acls: Prevents adding ACLs that grant public access.
# block_public_policy: Prevents bucket policies that allow public access.
# ignore_public_acls: Ensures the bucket ignores any public ACLs.
# restrict_public_buckets: Blocks any attempts to make the bucket public.