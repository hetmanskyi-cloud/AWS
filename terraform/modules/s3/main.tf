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

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-rep-${random_string.suffix.result}" # Bucket name format: <prefix>-<key>-rep-<suffix>

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

# --- S3 Bucket Ownership Controls for Default Region Buckets --- #
resource "aws_s3_bucket_ownership_controls" "default_region_bucket_ownership_controls" {
  # Configures S3 Bucket Ownership Controls for all default region buckets  
  for_each = tomap({
    for key, value in var.default_region_buckets :
    key => value if value.enabled
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id

  rule {
    object_ownership = "BucketOwnerPreferred" # Set Object Ownership to BucketOwnerPreferred to enable ACLs
  }

  depends_on = [aws_s3_bucket.default_region_buckets] # Explicit dependency
}

# --- SSE Configuration for Default Region Buckets EXCEPT ALB Logs Bucket --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "default_region_bucket_encryption" {
  # SSE for default region buckets
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && key != "alb_logs"
  })

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

  # --- Notes --- #
  # ALB Logs Bucket Encryption Exception:
  # The 'alb_logs' bucket is intentionally excluded from this resource and
  # configured separately in 'aws_s3_bucket_server_side_encryption_configuration.alb_logs_bucket'.
  # This is because ALB Access Logs only support SSE-S3 (AES256) encryption or no encryption.
  # SSE-KMS is not supported for ALB Access Logs delivery.
  # Therefore, 'alb_logs' bucket requires a dedicated SSE-S3 configuration (sse_algorithm = "AES256").
}

# --- SSE-S3 Configuration for ALB Logs Bucket --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs_bucket" {
  for_each = tomap({
    for key, value in var.default_region_buckets :
    key => value if value.enabled && key == "alb_logs"
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Only SSE-S3 (AES256) is supported for ALB logs.
    }
  }

  lifecycle {
    prevent_destroy = false
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
      sse_algorithm     = "aws:kms"                                                                                                    # KMS encryption algorithm
      kms_master_key_id = var.kms_replica_key_arn != null && var.kms_replica_key_arn != "" ? var.kms_replica_key_arn : var.kms_key_arn # Используем реплику ключа KMS
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
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Public Access Block for Replication Region Buckets --- #
resource "aws_s3_bucket_public_access_block" "replication_region_bucket_public_access_block" {
  # Public Access Block for replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket

  # Public Access Block settings - same for all buckets
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Set ACL for Logging Bucket --- #
# Grants S3 log delivery permissions for server access logging.
resource "aws_s3_bucket_acl" "logging_bucket_acl" {
  count  = var.default_region_buckets["logging"].enabled ? 1 : 0
  bucket = aws_s3_bucket.default_region_buckets["logging"].id

  acl = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.default_region_bucket_ownership_controls,
    aws_s3_bucket.default_region_buckets,
    aws_s3_bucket_logging.default_region_bucket_server_access_logging
  ]
}

# --- Server Access Logging for Default Region Buckets --- #
# Enables server access logging for selected S3 buckets.
# Logs are stored in the central 'logging' bucket if it is enabled.
resource "aws_s3_bucket_logging" "default_region_bucket_server_access_logging" {
  # Apply logging only to enabled buckets that have server_access_logging set to true,
  # the 'logging' bucket must be enabled,
  # AND exclude the 'logging' bucket itself (to avoid infinite recursion).
  for_each = tomap({
    for key, value in var.default_region_buckets :
    key => value
    if value.enabled
    && lookup(value, "server_access_logging", false)
    && var.default_region_buckets["logging"].enabled
    && key != "logging"
  })

  bucket        = aws_s3_bucket.default_region_buckets[each.key].id    # Source bucket
  target_bucket = aws_s3_bucket.default_region_buckets["logging"].id   # Logging destination
  target_prefix = "${var.name_prefix}/${each.key}-server-access-logs/" # Log path
}

# --- Random Suffix for Bucket Names --- #
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
#
# 1. Dynamic bucket creation from 'terraform.tfvars'.
# 2. Manages default & replication region buckets.
# 3. Unified config for versioning, notifications, encryption, public access block.
# 4. Comprehensive Logging Options: Implements two types of logging:
#     *   Centralized Bucket Logging Collection: Collects access logs from specified default region buckets into the central 'logging' bucket. Configured via the `logging` parameter in 'terraform.tfvars'.
#     *   Server Access Logging: Enables Server Access Logging for individual buckets in both default and replication regions. Logs are also directed to the central 'logging' bucket in the default region. Configured via the `access_logging` parameter in 'terraform.tfvars'.
# 5. Unique bucket names via random suffix.
# 6. Pre-create KMS key (var.kms_key_arn) & SNS topic (var.sns_topic_arn).
# 7. Bucket policies & IAM roles to be configured separately.
# 8. Consider lifecycle rules for cost optimization.