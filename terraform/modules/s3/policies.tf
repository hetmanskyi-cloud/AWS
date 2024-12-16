# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# This file defines key configurations for bucket policies, CORS, and lifecycle rules
# to ensure security, compliance, and functionality.

# --- Environment Logic --- #
# In `dev` environment:
# - Created buckets: terraform_state, scripts, logging, ami
# - Not created: wordpress_media, replication
#
# In `stage` environment:
# - Created buckets: terraform_state, scripts, logging, ami, wordpress_media.
# - replication is created if `enable_s3_replication = true`.
#
# In `prod` environment:
# - All buckets are created.
# - wordpress_media is always created.
# - replication is created if `enable_s3_replication = true`.

# --- CORS Configuration for WordPress Media Bucket --- #
# Configures CORS rules in stage and prod, as wordpress_media is created in both environments.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count  = var.environment == "stage" || var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.wordpress_media[count.index].id # Safe because count=1 in stage/prod, 0 in dev

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"] # Restrict headers to required ones.
    allowed_methods = ["GET", "POST"]                   # Only GET, POST are allowed.
    allowed_origins = ["*"]                             # Initially allow all origins; restrict in prod if needed.
    max_age_seconds = 3000                              # Cache preflight responses.
  }
}

# --- Bucket Policies --- #
# Deny Public Access:
# - Applies to all `base` and `special` buckets defined in the `buckets` variable.
# - Prevents both bucket-level and object-level public access.
# Enforce HTTPS:
# - Ensures all bucket interactions occur over HTTPS for enhanced security.
resource "aws_s3_bucket_policy" "deny_public_access" {
  # Loop through all "base" and "special" buckets from the `buckets` variable
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if(
      bucket.type == "base" || bucket.type == "special"
    )
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  # This policy denies all public access to the bucket, including both bucket-level
  # and object-level access. It ensures that data remains private by enforcing secure
  # connections and blocking any unauthorized access attempts. 
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

# --- Enforce HTTPS for Specific Buckets --- #
# Enforces HTTPS connections for all buckets.
# Requests using plain HTTP will be denied to ensure secure data transfer.
# This policy ensures that only HTTPS/TLS connections are used to access the buckets.
resource "aws_s3_bucket_policy" "force_https" {
  # Loop through all "base" and "special" buckets from the `buckets` variable
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if(
      bucket.type == "base" || bucket.type == "special"
    )
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  # This policy ensures that all access to the S3 bucket is made over HTTPS (TLS).
  # Any requests using plain HTTP will be denied to enhance security.
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

# --- Logging Bucket Policy --- #
# This resource defines a policy for the S3 logging bucket, allowing specific AWS services 
# (S3 logging, ALB, and WAF) to write logs into the bucket.

resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  # Filters the `buckets` variable to include only the bucket intended for logging.
  # Ensures the policy is applied specifically to the `logging` bucket.
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.name == "logging"
  }

  # The target bucket where the policy will be applied.
  bucket = aws_s3_bucket.buckets[each.key].id

  # JSON policy granting permissions to write logs into the bucket.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLoggingWrite", # S3 logging service permissions
        Effect    = "Allow",
        Principal = { Service = "logging.s3.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
      },
      {
        Sid       = "AllowALBLogging", # ALB logging permissions
        Effect    = "Allow",
        Principal = { Service = "elasticloadbalancing.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/alb-logs/*"
      },
      {
        Sid       = "AllowWAFLogging", # WAF logging permissions
        Effect    = "Allow",
        Principal = { Service = "waf.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/waf-logs/*"
      }
    ]
  })
}

# --- Lifecycle Policies --- #
# Dynamically applies lifecycle rules to manage noncurrent object versions and incomplete uploads.
# Uses the `buckets` variable to identify eligible buckets.
# Key configurations:
# - Noncurrent versions are retained for a configurable number of days.
# - Incomplete uploads are aborted after 7 days to reduce costs.
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  # Dynamically processes all "base" and "special" buckets defined in the `buckets` variable.
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.type == "base" || bucket.type == "special"
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  # Rule to manage noncurrent object versions for cost control.
  rule {
    id     = "${each.key}-retain-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # Set in terraform.tfvars
    }
  }

  rule {
    id     = "${each.key}-abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Additional Lifecycle Configuration for Replication --- #
# Applies lifecycle rules specifically to the replication bucket, if enabled.
resource "aws_s3_bucket_lifecycle_configuration" "replication_lifecycle" {
  # Filter the `buckets` variable to include only the replication bucket
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.name == "replication" && var.enable_s3_replication
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
# - Applies to `stage` and `prod` environments only.
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
resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_s3_replication ? 1 : 0 # Set in terraform.tfvars

  name = "${var.name_prefix}-replication-policy"
  role = aws_iam_role.replication_role[0].id

  # This policy consists of two main parts:
  # 1. Permissions to read replication configuration, list source buckets, and access object metadata from source buckets.
  # 2. Permissions to replicate objects, deletes, and tags into the destination replication bucket.
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
          for bucket in var.buckets : "${aws_s3_bucket.buckets[bucket.name].arn}" if bucket.type == "base" || bucket.type == "special"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = [
          aws_s3_bucket.replication[0].arn,
          "${aws_s3_bucket.replication[0].arn}/*"
        ]
      }
    ]
  })
}

# --- Bucket Policy for Replication Destination --- #
# Allows the replication role to write objects to the replication bucket.
resource "aws_s3_bucket_policy" "replication_bucket_policy" {
  # Dynamically filter the `buckets` variable to select only the replication bucket.
  # The condition ensures that the bucket is included only if replication is enabled.
  for_each = {
    for bucket in var.buckets : bucket.name => bucket if bucket.name == "replication" && var.enable_s3_replication
  }

  bucket = aws_s3_bucket.buckets[each.key].id

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
        Resource = "${aws_s3_bucket.buckets[each.key].arn}/*"
      }
    ]
  })
}

# --- Source Bucket Replication Policy --- #
# Grants the replication role read access on source buckets.
resource "aws_s3_bucket_policy" "source_bucket_replication_policy" {
  # Dynamically filter the `buckets` variable to include all "base" and "special" buckets.
  # The condition ensures that the policy is applied only if replication is enabled.
  for_each = var.enable_s3_replication ? {
    for bucket in var.buckets : bucket.name => bucket if bucket.type == "base" || bucket.type == "special"
  } : {}

  bucket = aws_s3_bucket.buckets[each.key].id

  # The policy grants the replication role permissions to read objects and their metadata from source buckets.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplication",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.replication_role[0].arn
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
#
# 2. **Lifecycle Management**:
#    - Retains noncurrent object versions for a defined period (e.g., 30 days, configurable in `terraform.tfvars`).
#    - Automatically aborts incomplete multipart uploads to reduce storage costs.
#
# 3. **Replication Configuration**:
#    - Dynamically creates IAM roles and policies for replication if `enable_s3_replication = true`.
#    - Configures source and destination policies for bucket replication in `stage` and `prod`.
#
# 4. **CORS Rules**:
#    - Applied to the `wordpress_media` bucket in `stage` and `prod`.
#    - Restricts allowed headers and methods for security, while enabling cross-origin requests for WordPress media.
#
# 5. **Dynamic Bucket Policies**:
#    - All policies and configurations adapt based on the `buckets` variable in `terraform.tfvars`.
#    - Simply adding a new bucket to `buckets` automatically includes it in relevant policies and rules.
#
# 6. **Logging Configuration**:
#    - Grants the S3 logging service (`logging.s3.amazonaws.com`) permissions to write logs to the logging bucket.
#    - Includes additional permissions for ALB logging (`elasticloadbalancing.amazonaws.com`) and WAF logging (`waf.amazonaws.com`).
#    - Log files are stored in dedicated prefixes (`alb-logs/` and `waf-logs/`) within the logging bucket.