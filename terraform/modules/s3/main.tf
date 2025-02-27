# --- Main Configuration for S3 Buckets --- #
# Defines S3 buckets and core configurations.

# --- Terraform Configuration --- #
# Defines Terraform provider and version.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- AWS Provider for Replication Region --- #
# Configures AWS provider for replication region.
provider "aws" {
  alias  = "replication"          # Replication provider alias
  region = var.replication_region # Replication region
}

# --- Default Region Buckets --- #
# Dynamically creates S3 buckets in the default region.
resource "aws_s3_bucket" "default_region_buckets" {
  # Dynamic buckets in default region
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled })

  provider = aws # Default AWS provider

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}" # Bucket name: <prefix>-<key>-<suffix>

  tags = {
    Name        = "${var.name_prefix}-${each.key}" # Name tag
    Environment = var.environment                  # Environment tag
  }

  force_destroy = true # WARNING: Enable ONLY for testing environments! Allows bucket deletion with non-empty contents.
}

# --- Replication Region Buckets --- #
# Dynamically creates S3 buckets in the replication region.
resource "aws_s3_bucket" "s3_replication_bucket" {
  # Dynamic buckets in replication region
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication # Replication AWS provider  

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}" # Bucket name: <prefix>-<key>-<suffix>

  tags = {
    Name        = "${var.name_prefix}-${each.key}" # Name tag (replication)
    Environment = var.environment                  # Environment tag
  }

  force_destroy = true # WARNING: Enable ONLY for testing environments! Allows bucket deletion with non-empty contents.
}

# --- Deploy WordPress Scripts --- #
# Deploys WordPress scripts to the 'scripts' S3 bucket.
resource "aws_s3_object" "deploy_wordpress_scripts_files" {
  # Conditional script deployment
  for_each = var.default_region_buckets["scripts"].enabled && var.enable_s3_script ? var.s3_scripts : {}

  bucket = aws_s3_bucket.default_region_buckets["scripts"].id # Target 'scripts' bucket
  key    = each.key                                           # S3 object key
  source = "${path.root}/${each.value}"                       # Local script path

  server_side_encryption = "aws:kms"       # KMS encryption
  kms_key_id             = var.kms_key_arn # KMS key ARN

  content_type = lookup({ ".sh" = "text/x-shellscript", ".php" = "text/php" }, substr(each.key, length(each.key) - 3, 4), "text/plain") # Content type by extension

  depends_on = [aws_s3_bucket.default_region_buckets] # Depends on default buckets

  tags = {
    Name        = "Deploy WordPress Script" # Name tag
    Environment = var.environment           # Environment tag
  }

  # --- Notes --- #
  # - Uploads scripts to 'scripts' bucket (defined in 'var.s3_scripts').
}

# --- All Buckets Notifications --- #
# Configures notifications for all enabled S3 buckets to a central SNS topic.
resource "aws_s3_bucket_notification" "all_buckets_notifications" {
  # Unified notifications for all enabled buckets
  for_each = tomap({ for key, value in merge(var.default_region_buckets, var.replication_region_buckets) : key => value if value.enabled })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id # Target bucket ID

  topic {
    topic_arn = var.sns_topic_arn                            # SNS topic ARN
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] # Object events: create & remove
  }

  # --- Notes --- #
  # - Notifications to central SNS topic for all enabled buckets.
}

# --- All Buckets Versioning --- #
# Enables versioning for all enabled S3 buckets (if versioning=true).
resource "aws_s3_bucket_versioning" "all_buckets_versioning" {
  # Unified versioning for all eligible buckets
  for_each = tomap({ for key, value in merge(var.default_region_buckets, var.replication_region_buckets) : key => value if value.enabled && value.versioning })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id # Target bucket ID

  versioning_configuration {
    status = "Enabled" # Enable versioning
  }

  # --- Notes --- #
  # - Versioning for enabled buckets (versioning=true).
}

# --- Logging Configuration (Default Region Buckets) --- #
# Enables access logging for default region S3 buckets (excluding the logging bucket).
resource "aws_s3_bucket_logging" "default_region_bucket_logging" {
  # Dynamic logging for default region buckets (excluding 'logging' bucket)
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if(value.enabled && (value.logging != null ? value.logging : false) && key != "logging" && var.default_region_buckets["logging"] != null && var.default_region_buckets["logging"].enabled) })

  bucket        = aws_s3_bucket.default_region_buckets[each.key].id  # Source bucket for logs
  target_bucket = aws_s3_bucket.default_region_buckets["logging"].id # Central logging bucket
  target_prefix = "${var.name_prefix}/${each.key}/"                  # Log prefix: <prefix>/<bucket_name>/

  # --- Notes --- #
  # - Centralized access logs for default region buckets in 'logging' bucket.
  # - Configured dynamically via 'logging' flag and excludes 'logging' bucket itself.
  # - Consider separate logging for replication buckets if needed.
}

# --- SSE Configuration for All Buckets --- #
# Enforces AWS KMS server-side encryption for all enabled S3 buckets.
resource "aws_s3_bucket_server_side_encryption_configuration" "all_buckets_encryption" {
  # Dynamic SSE for all enabled buckets (default & replication regions)
  for_each = tomap({ for key, value in merge(var.default_region_buckets, var.replication_region_buckets) : key => value if value.enabled })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"       # KMS encryption algorithm
      kms_master_key_id = var.kms_key_arn # KMS key ARN
    }
    bucket_key_enabled = true # Enable Bucket Key for cost optimization
  }

  lifecycle {
    prevent_destroy = false # Allow destroy for updates/replacements
  }

  # --- Notes --- #
  # - KMS SSE for all enabled buckets; unencrypted uploads denied (via policy).
  # - 'prevent_destroy = false' for updates.
  # - Ensure KMS key exists (var.kms_key_arn).
}

# --- Public Access Block for All Buckets --- #
# Enforces public access restrictions on all S3 buckets.
resource "aws_s3_bucket_public_access_block" "all_buckets_public_access_block" {
  # Dynamic Public Access Block for all enabled buckets
  for_each = tomap({ for key, value in merge(var.default_region_buckets, var.replication_region_buckets) : key => value if value.enabled })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.s3_replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  # Public Access Block settings - same for all buckets
  block_public_acls       = true # Block public ACLs
  block_public_policy     = true # Block public policies
  ignore_public_acls      = true # Ignore public ACLs
  restrict_public_buckets = true # Restrict public access

  # --- Notes --- #
  # - Restricts public access to all enabled buckets.
  # - Enforces security best practices.
  # - Unified configuration for default & replication regions.
}

## --- Random Suffix for Bucket Names --- ##
# Generates random suffix for unique S3 bucket names.
resource "random_string" "suffix" {
  length  = 5     # Suffix length: 5 chars
  special = false # No special chars
  upper   = false # No uppercase letters
  lower   = true  # Lowercase letters allowed
  numeric = true  # Numeric chars allowed

  # --- Notes --- #
  # - 5-char random suffix (lowercase, numeric).
  # - Ensures unique bucket names.
}

# --- Module Notes --- #
# General notes for the S3 module.

# 1. Dynamic bucket creation from 'terraform.tfvars'.
# 2. Manages default & replication region buckets.
# 3. Unified config for versioning, notifications, encryption, public access block.
# 4. Centralized logging (default region buckets only).
# 5. Unique bucket names via random suffix.
# 6. Pre-create KMS key (var.kms_key_arn) & SNS topic (var.sns_topic_arn).
# 7. Bucket policies & IAM roles to be configured separately.
# 8. Consider lifecycle rules for cost optimization.