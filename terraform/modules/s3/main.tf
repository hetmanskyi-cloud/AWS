# --- Main Configuration for S3 Buckets --- #
# Defines S3 buckets and core configurations.  Buckets are managed via 'var.buckets' in terraform.tfvars.

# --- Terraform Configuration --- #
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "replication"
  region = var.replication_region
}

# --- Dynamically Create S3 Buckets (Default Region) --- #
resource "aws_s3_bucket" "default_region_buckets" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value if value.enabled
  })

  provider = aws

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}"

  tags = {
    Name        = "${var.name_prefix}-${each.key}"
    Environment = var.environment
  }
}

# --- Dynamically Create Replication S3 Buckets (Replication Region) --- #
resource "aws_s3_bucket" "s3_replication_bucket" {
  for_each = tomap({
    for key, value in var.replication_region_buckets : key => value if value.enabled
  })

  provider = aws.replication

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}"

  tags = {
    Name        = "${var.name_prefix}-${each.key}"
    Environment = var.environment
  }
}

# --- Deploy WordPress Scripts to S3 --- #
resource "aws_s3_object" "deploy_wordpress_scripts_files" {
  for_each = var.default_region_buckets["scripts"].enabled && var.enable_s3_script ? var.s3_scripts : {}

  bucket = aws_s3_bucket.default_region_buckets["scripts"].id
  key    = each.key
  source = "${path.root}/${each.value}"

  server_side_encryption = "aws:kms"
  kms_key_id             = var.kms_key_arn

  content_type = lookup({
    ".sh"  = "text/x-shellscript",
    ".php" = "text/php"
  }, substr(each.key, length(each.key) - 3, 4), "text/plain")

  depends_on = [aws_s3_bucket.default_region_buckets]

  tags = {
    Name        = "Deploy WordPress Script"
    Environment = var.environment
  }

  # --- Notes --- #
  # Uploads WordPress scripts to the 'scripts' bucket.
  # Files are defined in 'var.s3_scripts'. Ensure files exist locally.
}

# --- S3 Buckets Notifications for All Buckets --- #
# Configures notifications for all enabled S3 buckets, across all regions.
# Dynamically applies notification settings to buckets defined in both `default_region_buckets` and `replication_region_buckets` variables.
resource "aws_s3_bucket_notification" "all_buckets_notifications" {
  # Combine default and replication region buckets for unified notification configuration
  for_each = tomap({
    for key, value in merge(
      var.default_region_buckets,
      var.replication_region_buckets,
    ) : key => value if value.enabled
  })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  # No need for 'provider = aws.replication' here, it's implicitly inherited from the 'bucket' argument.

  # --- Notes --- #
  # 1. Configures S3 bucket notifications for object creation and removal events for all enabled buckets.
  # 2. Notifications are sent to the SNS topic defined by 'var.sns_topic_arn'.
  # 3. Configured dynamically for buckets in both default and replication regions.
  # 4. Unified notification configuration for both default and replication region buckets.
}

# --- Versioning Configuration for All S3 Buckets --- #
# Dynamically enables versioning configuration for all enabled S3 buckets, across both default and replication regions.
resource "aws_s3_bucket_versioning" "all_buckets_versioning" {
  # Combine default and replication region buckets for unified versioning configuration
  for_each = tomap({
    for key, value in merge(
      var.default_region_buckets,
      var.replication_region_buckets,
    ) : key => value if value.enabled && value.versioning
  })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }

  # --- Notes --- #
  # 1. Enables versioning for all enabled buckets if 'versioning = true' in bucket configuration.
  # 2. Versioning ensures object history retention for recovery, auditing, and compliance.
  # 3. Configured dynamically for buckets in both default and replication regions.
  # 4. Consider lifecycle rules for managing noncurrent versions and cost optimization.
  # 5. Unified versioning configuration for both default and replication region buckets.
}

# --- Logging Configuration (Default Region Buckets) --- #
# Enables logging for enabled default region S3 buckets (excluding the logging bucket itself).
# Logs are centralized in a dedicated logging bucket within the default region.
resource "aws_s3_bucket_logging" "default_region_bucket_logging" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value if(value.enabled && (value.logging != null ? value.logging : false) && key != "logging" && var.default_region_buckets["logging"] != null && var.default_region_buckets["logging"].enabled)
  })

  bucket        = aws_s3_bucket.default_region_buckets[each.key].id
  target_bucket = aws_s3_bucket.default_region_buckets["logging"].id
  target_prefix = "${var.name_prefix}/${each.key}/"

  # --- Notes --- #
  # - Tracks access & operations for debugging, compliance, and audits (default region buckets only).
  # - Centralized logging to the 'logging' bucket in the default region.
  # - Configured dynamically via 'logging' flag in var.default_region_buckets.
  # - Logging bucket itself is excluded to prevent recursion.
  # - Ensure logging bucket has proper security (private, encrypted, IAM permissions).
  # - Logging for replication buckets is *not enabled in this configuration*.
  # - For enhanced security and audit of replicated data, *consider enabling separate logging for replication buckets*.
  # - Replicated *bucket access logs* (from default region buckets) are available in the central logging bucket, 
  #   but direct access logs for replication buckets themselves are not included by default.
}

# --- Server-Side Encryption (SSE) Configuration for All S3 Buckets --- #
# Enforces AWS KMS server-side encryption for all enabled S3 buckets and object uploads, across all regions.
# Dynamically applies SSE settings to all buckets defined in both `default_region_buckets` and `replication_region_buckets` variables.
resource "aws_s3_bucket_server_side_encryption_configuration" "all_buckets_encryption" {
  # Combine default and replication region buckets for unified encryption configuration
  for_each = tomap({
    for key, value in merge(
      var.default_region_buckets,
      var.replication_region_buckets,
    ) : key => value if value.enabled
  })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id

  # Server-Side Encryption Configuration
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"       # Use AWS KMS for encryption
      kms_master_key_id = var.kms_key_arn # KMS key for encrypting data
    }
    bucket_key_enabled = true # Optimizes costs for data encryption
  }

  lifecycle {
    prevent_destroy = false # Allow smooth updates and replacements
  }

  # --- Notes --- #
  # 1. Server-side encryption with AWS KMS is applied to all objects in all enabled buckets.
  # 2. Uploads of unencrypted objects are denied by bucket policy (ensure bucket policies are in place).
  # 3. 'prevent_destroy = false' allows updates and replacements.
  # 4. Ensure the KMS key (var.kms_key_arn) exists and has necessary permissions in all relevant regions.
  # 5. Unified encryption configuration for both default and replication region buckets.
}

# Enforces public access restrictions on all S3 buckets defined in terraform.tfvars, across all regions.
# Blocks public ACLs and policies, ignores existing public ACLs, and restricts public access.
resource "aws_s3_bucket_public_access_block" "all_buckets_public_access_block" {
  # Combine default and replication region buckets for unified public access block configuration
  for_each = tomap({
    for key, value in merge(
      var.default_region_buckets,
      var.replication_region_buckets,
    ) : key => value if value.enabled
  })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id

  # Public Access Block Settings (same for all buckets)
  block_public_acls       = true # Block all public ACLs (Access Control Lists)
  block_public_policy     = true # Ensure public bucket policies are blocked
  ignore_public_acls      = true # Ignore any public ACLs applied to the bucket
  restrict_public_buckets = true # Restrict the bucket from being publicly accessible

  # --- Notes --- #
  # 1. Restricts all public access to all enabled buckets, across both default and replication regions.
  # 2. Enforces consistent security best practices across all environments.
  # 3. Applied dynamically to buckets defined in terraform.tfvars (both default and replication regions).
  # 4. Unified public access block configuration for both default and replication region buckets.
}

## --- Random Suffix for Unique Bucket Names --- #
# Generates a random suffix to ensure globally unique S3 bucket names.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  lower   = true
  numeric = true

  # --- Notes --- #
  # -  Generates a 5-character random suffix (lowercase and numeric).
  # -  Ensures globally unique bucket names to avoid naming conflicts in AWS S3.
  # -  Appended to the base bucket name to create a unique bucket identifier.
}

# --- Notes --- #
# General notes for the S3 module.
# 1. Buckets are dynamically created based on configurations in 'terraform.tfvars'.
# 2. Module manages both default region buckets and replication region buckets.
# 3. Key bucket features (versioning, notifications, encryption, public access block) are configured in a unified manner for all enabled buckets.
# 4. Logging is configured separately and centrally for default region buckets only (replication buckets logging is omitted as redundant).
# 5. Bucket names are generated dynamically using a random suffix for global uniqueness.
# 6. Ensure KMS key (var.kms_key_arn) and SNS topic (var.sns_topic_arn) are pre-created and properly configured.
# 7. Bucket policies and IAM roles/policies for bucket access control are to be configured separately (outside this module, or added in future iterations).
# 8. Consider adding lifecycle rules for cost optimization and data management.