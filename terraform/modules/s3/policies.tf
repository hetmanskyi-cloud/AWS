# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- CORS Configuration for WordPress Media Bucket --- #

# Configures CORS rules for the `wordpress_media` bucket when enabled via the `enable_cors` variable.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count = var.enable_cors && lookup(var.buckets, "wordpress_media", false) ? 1 : 0

  bucket = aws_s3_bucket.wordpress_media[0].id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"] # Restrict headers to required ones.
    allowed_methods = ["GET", "POST"]                   # Only GET, POST are allowed.
    allowed_origins = var.allowed_origins               # Initially allow all origins; restrict in prod if needed.
    max_age_seconds = 3000                              # Cache preflight responses.
  }

  # --- Notes --- #
  # - `allowed_origins` is set to "*" for testing purposes.
  # - TODO: In production, replace `allowed_origins` with specific domain names for security.
  # - Consider restricting allowed methods to necessary ones only.
}

# --- Bucket Policies --- #

# Deny Public Access
resource "aws_s3_bucket_policy" "deny_public_access" {
  for_each = { for key, value in var.buckets : key => value if value }

  bucket = aws_s3_bucket.buckets[each.key].id

  # This policy denies all public access to the bucket, including both bucket-level and object-level access
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyPublicAccess",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.buckets[each.key].arn,
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

# Enforce HTTPS
resource "aws_s3_bucket_policy" "force_https" {
  for_each = { for key, value in var.buckets : key => value if value }

  bucket = aws_s3_bucket.buckets[each.key].id

  # This policy ensures that all access to the S3 bucket is made over HTTPS (TLS).
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnforceTLS",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.buckets[each.key].arn,
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Logging Bucket Policy
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  for_each = tomap({
    for key, value in var.buckets : key => value if key == "logging" && value && lookup(aws_s3_bucket.buckets, key, null) != null
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  depends_on = [aws_s3_bucket.buckets]

  # JSON policy granting permissions to write logs into the bucket.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLoggingWrite",
        Effect    = "Allow",
        Principal = { Service = "logging.s3.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
      },
      {
        Sid       = "AllowALBLogging",
        Effect    = "Allow",
        Principal = { Service = "elasticloadbalancing.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/alb-logs/*"
      },
      {
        Sid       = "AllowWAFLogging",
        Effect    = "Allow",
        Principal = { Service = "waf.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/waf-logs/*"
      },
      {
        Sid       = "AllowDeliveryLogsWrite",
        Effect    = "Allow",
        Principal = { Service = "delivery.logs.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/alb-logs/*"
      }
    ]
  })
}

# --- Lifecycle Policies --- #

# General Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = { for key, value in var.buckets : key => value if value }

  bucket = aws_s3_bucket.buckets[each.key].id

  # Rule to manage noncurrent object versions for cost control.
  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Set in terraform.tfvars
    }
  }

  # Rule to automatically abort incomplete multipart uploads.
  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Additional rule for 'scripts' bucket to delete old versions only
  dynamic "rule" {
    for_each = each.key == "scripts" ? [1] : []

    content {
      id     = "scripts-delete-old-versions"
      status = "Enabled"

      noncurrent_version_expiration {
        noncurrent_days = 30 # Delete old versions after 30 days
      }
    }
  }

  # Additional rule for 'logging' bucket to delete old logs
  dynamic "rule" {
    for_each = each.key == "logging" ? [1] : []

    content {
      id     = "delete-old-logs"
      status = "Enabled"

      expiration {
        days = 30 # Delete logs after 30 days
      }
    }
  }
}

# --- Replication Configuration --- #

# --- Replication Bucket Lifecycle Rules --- #
# Defines lifecycle rules for the replication bucket.
# This resource is created only if replication is enabled via `enable_s3_replication`.
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  for_each = {
    for key, value in var.buckets : key => value
    if key == "replication" && lookup(var.buckets, key, false) && var.enable_s3_replication
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  # Retain noncurrent object versions for a defined period
  rule {
    id     = "replication-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Set in terraform.tfvars
    }
  }

  # Automatically abort incomplete multipart uploads after 7 days
  rule {
    id     = "replication-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- IAM Role for Replication --- #
# This role allows S3 to replicate objects between buckets for cross-region replication.
# - Created only when `enable_s3_replication = true` in `terraform.tfvars`.
resource "aws_iam_role" "replication_role" {
  count = var.enable_s3_replication ? 1 : 0 # Dynamically created based on replication flag.

  name = "${var.name_prefix}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-replication-role"
    Environment = var.environment
  }
}

# --- Replication IAM Policy --- #
# This policy grants the replication role permissions to perform actions necessary for cross-region replication.
# Ensure that both source and destination buckets exist and are properly configured before enabling replication.
resource "aws_iam_role_policy" "replication_policy" {
  count = lookup(var.buckets, "replication", false) && var.enable_s3_replication ? 1 : 0 # Set in terraform.tfvars

  name = "${var.name_prefix}-replication-policy"
  role = aws_iam_role.replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ],
        Resource = [
          for key in keys(var.buckets) : aws_s3_bucket.buckets[key].arn if lookup(var.buckets, key, false)
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = length(aws_s3_bucket.replication) > 0 ? aws_s3_bucket.replication[0].arn : null
      }
    ]
  })
  # Notes:
  # 1. Ensure source buckets exist and are properly configured before enabling replication.
  # 2. The replication IAM role and policies are dynamically created for maximum flexibility.
  # 3. Additional permissions can be added to the IAM policies as needed for custom workflows.
}

# --- Bucket Policy for Replication Destination --- #
# Allows the replication role to write objects to the replication bucket.
# Created dynamically based on the `buckets` variable and `enable_s3_replication` flag.
resource "aws_s3_bucket_policy" "replication_bucket_policy" {
  count = lookup(var.buckets, "replication", false) && var.enable_s3_replication ? 1 : 0

  bucket = aws_s3_bucket.buckets["replication"].id

  # The policy grants the replication role permissions to replicate objects into this bucket.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowS3Replication",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.replication_role[0].arn
        },
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = "${aws_s3_bucket.buckets["replication"].arn}/*"
      }
    ]
  })
}

# --- Source Bucket Replication Policy --- #
# Grants the replication role read access on source buckets.
# Ensure that both source and destination buckets exist and are properly configured before enabling replication.
resource "aws_s3_bucket_policy" "source_bucket_replication_policy" {
  for_each = { for key, value in var.buckets : key => value if value && var.enable_s3_replication }

  bucket = aws_s3_bucket.buckets[each.key].id

  # The policy grants the replication role permissions to read objects and their metadata from source buckets.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplication",
        Effect = "Allow",
        Principal = {
          AWS = length(aws_iam_role.replication_role) > 0 ? aws_iam_role.replication_role[0].arn : null
        },
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.buckets[each.key].arn}",
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ]
      }
    ]
  })
}

# --- Notes --- #
# 1. **Security Policies**:
#    - Denies all public access via ACLs and bucket policies (DenyPublicAccess).
#    - Enforces HTTPS-only access (EnforceTLS) to enhance security.
#    - The replication destination bucket must allow the replication role to write data.
#    - Source buckets should have minimal permissions necessary for replication.
#
# 2. **Lifecycle Management**:
#    - Retains noncurrent object versions for a defined period to optimize costs.
#    - Automatically aborts incomplete multipart uploads to reduce storage usage.
#    - In production, additional lifecycle policies may be introduced to automatically delete temporary files 
#      (e.g., logs, intermediate CI/CD artifacts) to optimize storage and cost.
#
# 3. **Replication Configuration**:
#    - Dynamically creates IAM roles and policies for replication if `enable_s3_replication = true`.
#    - Grants replication permissions dynamically based on the `buckets` variable.
#    - Ensure that the replication role exists before enabling policies.
#
# 4. **CORS Rules**:
#    - Applied to the `wordpress_media` bucket if `enable_cors = true`.
#    - Restricts allowed headers and methods for security, while enabling cross-origin requests.
#
# 5. **Dynamic Configuration**:
#    - Buckets are dynamically managed via the `buckets` variable.
#    - Simply adding a new bucket to `buckets` automatically includes it in relevant policies and rules.
#    - Ensure consistency in naming and regional settings across environments.
#
# 6. **Logging Configuration**:
#    - Grants the S3 logging service permissions to write logs to the logging bucket.
#    - Includes additional permissions for ALB and WAF logs.
#
# 7. **Troubleshooting Tips**:
#    - Check IAM policies and bucket policies if replication fails.
#    - Ensure that the replication role has appropriate permissions for cross-region replication.
#    - Review bucket configurations and permissions for correct integration.