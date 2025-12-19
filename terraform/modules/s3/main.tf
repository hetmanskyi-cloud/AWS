resource "aws_s3_bucket" "default_region_buckets" {
  # checkov:skip=CKV_AWS_145:Encryption is configured via a separate aws_s3_bucket_server_side_encryption_configuration resource, which is a valid approach that checkov does not detect.
  # Dynamic buckets in default region
  # If the Terraform state bucket (${var.s3_terraform_state_bucket_key}) is included, additional precautions are needed.
  for_each = tomap({ for key, value in var.default_region_buckets : key => value if value.enabled })

  provider = aws # Default AWS provider

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}" # Bucket name: <prefix>-<key>-<suffix>

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-${each.key}"
  })

  # WARNING: Enable ONLY for testing environments!
  # CRITICAL WARNING: FOR DEVELOPMENT/SANDBOX ONLY!
  # Setting 'force_destroy' to 'true' allows 'terraform destroy' to delete buckets even if they contain objects.
  # This WILL lead to irreversible data loss in production.
  # This must be set to 'false' or removed for any staging or production environment.
  force_destroy = true # Allows deletion with non-empty contents.

  # --- Lifecycle Configuration --- #
  # WARNING: The following lifecycle block, if enabled, will apply to ALL S3 buckets created by this module.
  # Use this only in production environments to prevent accidental deletion of important buckets.
  #
  # - force_destroy = false    → blocks deletion of buckets containing objects
  # - prevent_destroy = true   → protects bucket from deletion via 'terraform destroy' or accidental removal
  #
  # To enable strict protection, manually uncomment the block below.
  # If you need to apply protection **only to specific buckets** (e.g., '${var.s3_terraform_state_bucket_key}'), implement per-resource logic manually.

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# --- Replication Region Buckets --- #
# Dynamically creates S3 buckets in the replication region.
# Cross-region server access logging is not supported by AWS.

resource "aws_s3_bucket" "s3_replication_bucket" {
  # checkov:skip=CKV_AWS_18:Access logging is not configured because AWS does not support cross-region S3 access logging.
  # Dynamic buckets in replication region
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication # Replication AWS provider

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-rep-${random_string.suffix.result}" # Bucket name format: <prefix>-<key>-rep-<suffix>

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-${each.key}"
  })

  force_destroy = true # WARNING: Enable ONLY for testing environments! Allows bucket deletion with non-empty contents.
}

# --- Deploy WordPress Scripts --- #
# Uploads WordPress installation and configuration scripts to the 'scripts' S3 bucket.
# Scripts are loaded from the local project directory and stored in S3 for use during EC2 provisioning.
resource "aws_s3_object" "deploy_wordpress_scripts_files" {
  # Conditional script deployment
  for_each = can(var.default_region_buckets[var.s3_scripts_bucket_key].enabled) ? var.s3_scripts : {}

  bucket = aws_s3_bucket.default_region_buckets[var.s3_scripts_bucket_key].id # Target 'scripts' bucket
  key    = each.key                                                           # S3 object key
  source = "${path.root}/${each.value}"                                       # Local script path

  server_side_encryption = "aws:kms"       # KMS encryption
  kms_key_id             = var.kms_key_arn # KMS key ARN

  content_type = lookup(
    { ".sh" = "text/x-shellscript", ".php" = "text/php" }, # Content type by extension
    substr(each.key, length(each.key) - 3, 4),
    "text/plain"
  )

  depends_on = [aws_s3_bucket.default_region_buckets] # Depends on default buckets

  tags = merge(var.tags, {
    Name = "Deploy WordPress Script"
  })

  # Notes:
  # - Uploads scripts to 'scripts' bucket (defined in 'var.s3_scripts').
  # - All WordPress-related scripts are uploaded to the S3 bucket named 'scripts'.
  # - These scripts are always pulled from S3 during EC2 initialization via user_data.
  # - The 'scripts' bucket MUST be enabled in terraform.tfvars for this process to succeed.
}

# --- Generic SNS Notifications for Default Region Buckets --- #
resource "aws_s3_bucket_notification" "default_region_bucket_sns_notifications" {
  # This resource configures a generic SNS notification for most default region buckets.
  # It explicitly excludes buckets like 'wordpress_media', which are expected to have
  # their own dedicated and more complex notification configuration.
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && key != "wordpress_media"
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket ID

  topic {
    topic_arn = var.sns_topic_arn      # SNS topic ARN
    events    = ["s3:ObjectRemoved:*"] # Example: notify on object deletion
  }
}



# --- Replication Region Buckets Notifications --- #
resource "aws_s3_bucket_notification" "replication_region_bucket_sns_notifications" {
  # Unified notifications for all enabled replication region buckets
  for_each = tomap({ for key, value in var.replication_region_buckets : key => value if value.enabled })

  provider = aws.replication
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target bucket ID

  topic {
    topic_arn = var.replication_region_sns_topic_arn # Replication region SNS topic ARN
    events    = ["s3:ObjectRemoved:*"]               # Object events: remove
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

# --- S3 Bucket Ownership Controls for Default Region (ACLs Enabled for Logs) --- #
# Configures S3 Bucket Ownership Controls for buckets requiring ACLs for logging delivery.

resource "aws_s3_bucket_ownership_controls" "default_region_logging_ownership" {
  # checkov:skip=CKV2_AWS_65:BucketOwnerPreferred is required for log-receiving buckets where services like ALB and S3 Access Logging need to write using ACLs.
  # Apply to enabled default region buckets that require ACLs for log delivery
  for_each = tomap({
    for key, value in var.default_region_buckets :
    key => value if value.enabled && contains([var.s3_logging_bucket_key, var.s3_alb_logs_bucket_key, var.s3_cloudtrail_bucket_key], key)
    # Filter includes 'logging' (S3 access logs), 'alb_logs', and 'cloudtrail'
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id

  rule {
    object_ownership = "BucketOwnerPreferred" # Set Object Ownership to BucketOwnerPreferred to enable ACLs
  }

  depends_on = [aws_s3_bucket.default_region_buckets] # Explicit dependency on bucket creation
}

# --- S3 Bucket Ownership Controls for Default Region (ACLs Disabled) --- #
# Configures S3 Bucket Ownership Controls for default region buckets where ACLs are not required.
resource "aws_s3_bucket_ownership_controls" "default_region_other_ownership" {
  # Apply to enabled default region buckets that do NOT require ACLs
  for_each = tomap({
    for key, value in var.default_region_buckets :
    key => value if value.enabled && !contains([var.s3_logging_bucket_key, var.s3_alb_logs_bucket_key, var.s3_cloudtrail_bucket_key], key)
    # Filter excludes 'logging', 'alb_logs', and 'cloudtrail'
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced" # Set Object Ownership to BucketOwnerEnforced to disable ACLs and enforce bucket owner
  }

  depends_on = [aws_s3_bucket.default_region_buckets] # Explicit dependency on bucket creation
}


# --- S3 Bucket Ownership Controls for Replication Region (ACLs Disabled) --- #
# Configures S3 Bucket Ownership Controls for replication region buckets.
resource "aws_s3_bucket_ownership_controls" "replication_region_ownership" {
  # Apply to enabled replication region buckets
  for_each = tomap({
    for key, value in var.replication_region_buckets :
    key => value if value.enabled
  })

  provider = aws.replication # Use the replication AWS provider

  # Target bucket is from the replication region bucket resource
  bucket = aws_s3_bucket.s3_replication_bucket[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced" # Set Object Ownership to BucketOwnerEnforced to disable ACLs and enforce bucket owner
  }

  depends_on = [aws_s3_bucket.s3_replication_bucket] # Explicit dependency on replication bucket creation
}

# --- SSE Configuration for Default Region Buckets EXCEPT ALB Logs Bucket --- #
resource "aws_s3_bucket_server_side_encryption_configuration" "default_region_bucket_encryption" {
  # SSE for default region buckets
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && key != var.s3_alb_logs_bucket_key
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

  # Notes:
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
    key => value if value.enabled && key == var.s3_alb_logs_bucket_key
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
      kms_master_key_id = var.kms_replica_key_arn != null && var.kms_replica_key_arn != "" ? var.kms_replica_key_arn : var.kms_key_arn # Use KMS replica key
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
# This resource is created only if the 'logging' bucket itself is enabled.
resource "aws_s3_bucket_acl" "logging_bucket_acl" {
  count  = try(var.default_region_buckets[var.s3_logging_bucket_key].enabled, false) ? 1 : 0
  bucket = aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].id

  acl = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.default_region_logging_ownership["logging"],
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
    && can(var.default_region_buckets[var.s3_logging_bucket_key].enabled)
    && key != var.s3_logging_bucket_key
  })

  bucket        = aws_s3_bucket.default_region_buckets[each.key].id                  # Source bucket
  target_bucket = aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].id # Logging destination
  target_prefix = "${var.name_prefix}/${each.key}-server-access-logs/"               # Log path
}

# --- Random Suffix for Bucket Names --- #
# Generates random suffix for unique S3 bucket names.
resource "random_string" "suffix" {
  length  = 5     # Suffix length: 5 chars
  special = false # No special chars
  upper   = false # No uppercase letters
  lower   = true  # Lowercase letters allowed
  numeric = true  # Numeric chars allowed

  # Notes:
  # - 5-char random suffix (lowercase, numeric).
  # - Ensures unique bucket names.
}

# --- Notes --- #
# 1. Dynamic bucket creation from 'terraform.tfvars'.
# 2. Manages default & replication region buckets.
# 3. Configures versioning, notifications, encryption, and public access block.
# 4. S3 Bucket Ownership Controls Strategy:
#    * Default Region (Log Receivers: logging, alb_logs, cloudtrail): 'BucketOwnerPreferred' (ACLs enabled for logging delivery).
#    * Default Region (Others): 'BucketOwnerEnforced' (ACLs disabled, policy-based control).
#    * Replication Region: 'BucketOwnerEnforced' (ACLs disabled, policy-based control).
# 5. Server Access Logging (Default Region, Centralized):
#    * Default region buckets only (AWS cross-region limitation).
#    * Enabled via `server_access_logging` in 'terraform.tfvars' (except 'logging' bucket).
#    * Logs stored in 'logging' bucket (default region), which requires 'BucketOwnerPreferred' & 'log-delivery-write' ACL.
# 6. Unique bucket names via random suffix.
# 7. Requires pre-created KMS key (var.kms_key_arn) & SNS topic (var.sns_topic_arn).
# 8. Bucket policies & IAM roles to be configured separately.
# 9. Consider lifecycle rules for cost optimization.
