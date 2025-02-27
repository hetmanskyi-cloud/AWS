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

# --- All Buckets Notifications (Default Region) --- #
resource "aws_s3_bucket_notification" "default_region_bucket_notifications" {
  # Unified notifications for all enabled default region buckets
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket ID

  topic {
    topic_arn = var.sns_topic_arn                            # SNS topic ARN
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] # Object events: create & remove
  }
}

# --- Replication Region Buckets Notifications --- #
resource "aws_s3_bucket_notification" "replication_region_bucket_notifications" {
  # Unified notifications for all enabled replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket ID

  topic {
    topic_arn = var.replication_region_sns_topic_arn         # Replication region SNS topic ARN
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] # Object events: create & remove
  }
}

# --- Default Region Buckets Versioning --- #
resource "aws_s3_bucket_versioning" "default_region_bucket_versioning" {
  # Versioning for eligible default region buckets
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled && value.versioning })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket ID

  versioning_configuration {
    status = "Enabled" # Enable versioning
  }
}

# --- Replication Region Buckets Versioning --- #
resource "aws_s3_bucket_versioning" "replication_region_bucket_versioning" {
  # Versioning for eligible replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled && value.versioning })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket ID

  versioning_configuration {
    status = "Enabled" # Enable versioning
  }
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

# --- SSE Configuration for Default Region Buckets --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "default_region_bucket_encryption" {
  # SSE for default region buckets
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

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
}

# --- SSE Configuration for Replication Region Buckets --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "replication_region_bucket_encryption" {
  # SSE for replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket

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
}

# --- Public Access Block for Default Region Buckets --- #
resource "aws_s3_bucket_public_access_block" "default_region_bucket_public_access_block" {
  # Public Access Block for default region buckets
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  # Public Access Block settings - same for all buckets
  block_public_acls       = true # Block public ACLs
  block_public_policy     = true # Block public policies
  ignore_public_acls      = true # Ignore public ACLs
  restrict_public_buckets = true # Restrict public access
}

# --- Public Access Block for Replication Region Buckets --- #
resource "aws_s3_bucket_public_access_block" "replication_region_bucket_public_access_block" {
  # Public Access Block for replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket

  # Public Access Block settings - same for all buckets
  block_public_acls       = true # Block public ACLs
  block_public_policy     = true # Block public policies
  ignore_public_acls      = true # Ignore public ACLs
  restrict_public_buckets = true # Restrict public access
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