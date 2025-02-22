# --- Main Configuration for S3 Buckets --- #
# Defines S3 buckets and core configurations.  Buckets are managed via 'var.buckets' in terraform.tfvars.

# --- Terraform Configuration --- #
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replication]
    }
  }
}

# --- Dynamically Create S3 Buckets --- #
resource "aws_s3_bucket" "buckets" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = "${lower(var.name_prefix)}-${replace(each.key, "_", "-")}-${random_string.suffix.result}"

  tags = {
    Name        = "${var.name_prefix}-${each.key}"
    Environment = var.environment
  }
}

# --- Deploy WordPress Scripts to S3 --- #
resource "aws_s3_object" "deploy_wordpress_scripts_files" {
  for_each = var.buckets["scripts"].enabled && var.enable_s3_script ? var.s3_scripts : {}

  bucket = aws_s3_bucket.buckets["scripts"].id
  key    = each.key
  source = "${path.root}/${each.value}"

  server_side_encryption = "aws:kms"
  kms_key_id             = var.kms_key_arn

  content_type = lookup({
    ".sh"  = "text/x-shellscript",
    ".php" = "text/php"
  }, substr(each.key, length(each.key) - 3, 4), "text/plain")

  depends_on = [aws_s3_bucket.buckets]

  tags = {
    Name        = "Deploy WordPress Script"
    Environment = var.environment
  }

  # --- Notes --- #
  # Uploads WordPress scripts to the 'scripts' bucket.
  # Files are defined in 'var.s3_scripts'.  Ensure files exist locally.
}

# --- Replication Configuration for Source Buckets --- #
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? 1 : 0

  bucket = aws_s3_bucket.buckets["replication"].id

  role = aws_iam_role.replication_role[0].arn

  dynamic "rule" {
    for_each = {
      for bucket_name, value in var.buckets : bucket_name => value
      if value.enabled && value.replication && var.buckets["replication"].enabled && var.buckets["replication"].replication
    }

    content {
      id     = "${rule.key}-replication"
      status = "Enabled"

      filter {
        prefix = "${rule.key}/"
      }

      destination {
        bucket        = aws_s3_bucket.buckets["replication"].arn
        storage_class = "STANDARD"
      }
    }
  }

  depends_on = [aws_s3_bucket.buckets["replication"]]

  # --- Notes --- #
  # Configures cross-region replication.
  # Requires pre-existing source and destination buckets.
  # Ensure the 'replication' destination bucket is correctly configured.
  # Replication rules are applied to at least one enabled source bucket.
}

# --- S3 Bucket Notifications --- #
resource "aws_s3_bucket_notification" "bucket_notifications" {
  for_each = {
    for key, value in var.buckets : key => value if value.enabled
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  # --- Notes --- #
  # Configures notifications for object creation and deletion events.
  # Sends notifications to the specified SNS topic.
  # Consider adding filters in production to reduce notification volume.
  # Example filters: prefix, suffix.
}

# --- Versioning Configuration for Buckets --- #
# This file dynamically enables versioning for S3 buckets.
# Versioning retains object history for recovery, auditing, and compliance.
# Buckets to enable versioning on are defined in the 'buckets' variable in terraform.tfvars.
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled && value.versioning
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }

  # --- Notes --- #
  # 1. Versioning ensures object history retention for recovery, auditing, and compliance.
  # 2. Versioning is enabled based on the 'versioning' key in the 'buckets' variable in terraform.tfvars.
  # 3. Enable versioning for critical buckets, especially in production.
  # 4. Pair versioning with lifecycle rules to manage noncurrent versions and costs.
  # 5. Versioning is applied dynamically based on the 'buckets' variable.
  # 6. Versioning can be enabled for existing buckets without recreation.
  #    Objects uploaded before enabling versioning have a "null version".
}

# --- Logging Configuration --- #
# Enables logging for enabled S3 buckets (excluding the logging bucket itself).
# Logs are stored in a centralized logging bucket under dedicated prefixes.
resource "aws_s3_bucket_logging" "bucket_logging" {
  for_each = {
    for key, value in var.buckets : key => value if(
      value.enabled &&
      (value.logging != null ? value.logging : false) && # Исправлено здесь
      key != "logging" &&
      var.buckets["logging"] != null &&
      var.buckets["logging"].enabled
    )
  }

  bucket        = aws_s3_bucket.buckets[each.key].id
  target_bucket = aws_s3_bucket.buckets["logging"].id
  target_prefix = "${var.name_prefix}/${each.key}/"

  # --- Notes --- #
  # 1. Logging tracks bucket access and operations for debugging, compliance, and audits.
  # 2. Logs are centralized in a dedicated logging bucket.
  # 3. Logging is dynamically configured based on the 'logging' key in the 'buckets' variable in terraform.tfvars.
  # 4. The logging bucket itself is excluded from logging to prevent recursion.  If audit logging for the logging bucket is required, use a separate audit log bucket.
  # 5. Ensure the logging bucket is private, encrypted, and has appropriate IAM permissions for log delivery (s3:PutObject).
}

# --- Server-Side Encryption (SSE) Configuration --- #
# Enforces AWS KMS server-side encryption for all buckets and object uploads.
# Dynamically applies SSE settings to all buckets defined in the `buckets` variable.
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  # Apply encryption settings to all defined buckets
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = aws_s3_bucket.buckets[each.key].id

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
  # 1. Server-side encryption with AWS KMS is applied to all objects.
  # 2. Uploads of unencrypted objects are denied by bucket policy.
  # 3. 'prevent_destroy = false' allows updates and replacements.
  # 4. Ensure the KMS key (var.kms_key_arn) exists and has necessary permissions.
}

# --- Public Access Block Configuration --- #
# Enforces public access restrictions on all S3 buckets defined in terraform.tfvars.
# Blocks public ACLs and policies, ignores existing public ACLs, and restricts public access.
# Dynamically applies public access restrictions to all buckets as defined in the `buckets` variable.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  # Dynamically process all buckets
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled # Apply only to enabled buckets
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

  # --- Notes --- #
  # 1. Restricts all public access to the defined buckets.
  # 2. Ensures consistent security best practices across all environments.
  # 3. Applies dynamically to buckets defined in terraform.tfvars.
}

# --- Random String Configuration --- #
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# --- Notes --- #
# General notes for the S3 module.
# 1. Buckets are managed via 'var.buckets' in terraform.tfvars.
# 2. Ensure all required keys (enabled, versioning, replication, logging, scripts) exist in 'var.buckets'.
# 3. 'depends_on' should point to 'aws_s3_bucket.buckets'.
# 4. 'count' or 'for_each' should use conditional logic based on 'var.buckets["bucket_name"].enabled'.
# 5. Bucket names are generated dynamically.
# 6. Consider adding filters to S3 Bucket Notifications in production.
# 7. Policies, IAM, and lifecycle rules are configured in separate files.