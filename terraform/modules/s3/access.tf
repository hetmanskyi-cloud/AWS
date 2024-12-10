# --- Public Access Block Configuration for S3 Buckets --- #
# This file enforces a public access block on all S3 buckets to prevent unintended public exposure.

# --- Local Variable for Buckets --- #
# Define a list of buckets requiring a public access block.
# All buckets are assumed private and are protected from accidental public access.
locals {
  buckets_with_public_access_block = {
    terraform_state   = aws_s3_bucket.terraform_state.id   # Terraform state bucket
    wordpress_media   = aws_s3_bucket.wordpress_media.id   # WordPress media bucket
    wordpress_scripts = aws_s3_bucket.wordpress_scripts.id # WordPress scripts bucket
    logging           = aws_s3_bucket.logging.id           # Logging bucket
  }
}

# --- Public Access Block Resource --- #
# Applies a public access block configuration to all S3 buckets listed in the local variable.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  # Loop through all buckets defined in the local variable
  for_each = merge(
    {
      terraform_state   = aws_s3_bucket.terraform_state.id   # Terraform state bucket
      wordpress_media   = aws_s3_bucket.wordpress_media.id   # WordPress media bucket
      wordpress_scripts = aws_s3_bucket.wordpress_scripts.id # WordPress scripts bucket
      logging           = aws_s3_bucket.logging.id           # Logging bucket
    },
    var.enable_s3_replication ? { replication = aws_s3_bucket.replication[0].id } : {} # Include replication bucket if enabled
  )

  # Target bucket
  bucket = each.value

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
#
# Bucket Replication:
# If `enable_s3_replication` is set to `true`, the replication bucket will automatically
# be included in the `for_each` loop, ensuring it also adheres to public access restrictions.
# This dynamic inclusion ensures the replication bucket inherits the same strict security
# configurations as other buckets, maintaining consistent policies across all S3 resources.