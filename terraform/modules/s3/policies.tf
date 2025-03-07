# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- WordPress Media Bucket CORS Config --- #
# Configures CORS for 'wordpress_media' bucket.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count = var.default_region_buckets["wordpress_media"].enabled && var.enable_cors ? 1 : 0 # Conditional CORS config

  bucket = aws_s3_bucket.default_region_buckets["wordpress_media"].id # Target bucket

  cors_rule {
    allowed_headers = ["Content-Type"] # Allowed headers: Content-Type
    allowed_methods = ["GET"]          # Allowed methods: GET

    # WARNING: Restrict 'allowed_origins' in production!
    allowed_origins = var.allowed_origins # Allowed origins (variable)
    max_age_seconds = 3000                # Cache preflight: 3000s
  }

  # --- CORS Notes --- #
  # 1. Purpose: Browser access to 'wordpress_media' bucket.
  # 2. Security: CRITICAL! Restrict 'allowed_origins' in production!
  # 3. Methods: GET only (read-only).
  # 4. Headers: Content-Type only (security best practice).
}

# --- Enforce HTTPS Policy for Default Region Buckets --- #
resource "aws_s3_bucket_policy" "default_region_enforce_https_policy" {
  # HTTPS policy for default region buckets (EXCLUDING logging bucket)
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value if value.enabled && key != "logging"
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Target bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket.default_region_buckets] # Depends on buckets
}

# --- Unified Replication Destination Bucket Policy --- #
# Combines HTTPS enforcement and replication permissions in one policy.
resource "aws_s3_bucket_policy" "replication_destination_policy" {
  for_each = length([
    for value in var.default_region_buckets : value
    if value.enabled && value.replication
    ]) > 0 ? tomap({
    for key, value in var.replication_region_buckets :
    key => value
    if value.enabled
  }) : {} # Conditional policy creation

  provider = aws.replication                                  # Explicitly specify replication provider
  bucket   = aws_s3_bucket.s3_replication_bucket[each.key].id # Target replication bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Enforce HTTPS Only
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.s3_replication_bucket[each.key].arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      # Allow replication role to write objects to the destination bucket
      {
        Sid    = "AllowReplicationWrite"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.replication_role[0].arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:PutObject",   # Allow writing objects
          "s3:PutObjectAcl" # Allow setting ACLs for replicated objects
        ]
        Resource = [
          "${aws_s3_bucket.s3_replication_bucket[each.key].arn}/*",
          aws_s3_bucket.s3_replication_bucket[each.key].arn
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket.s3_replication_bucket, aws_iam_role.replication_role] # Ensure dependencies exist before applying
}

# Retrieve AWS ELB service account ARN for the specified region
data "aws_elb_service_account" "main" {
  region = var.aws_region
}

# Generate IAM policy document for S3 logging bucket permissions
data "aws_iam_policy_document" "logging_bucket_policy" {

  # Allow ALB Service to check bucket ACL
  statement {
    sid     = "AllowELBLogDeliveryACLCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["logging"].arn
    ]
  }

  # Allow ALB AWS Account to check bucket ACL
  statement {
    sid     = "AllowELBAccountGetBucketAcl"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["logging"].arn
    ]
  }

  # Allow ALB service to write logs with proper ACL
  statement {
    sid     = "AllowELBLogDeliveryPutObject"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/AWSLogs/${var.aws_account_id}/elasticloadbalancing/${var.aws_region}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Allow ALB AWS account to put objects (with ACL)
  statement {
    sid     = "AllowELBAccountPutObject"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/AWSLogs/${var.aws_account_id}/elasticloadbalancing/${var.aws_region}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Allow S3 server access logging service
  statement {
    sid     = "S3LogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }
  }

  # Enforce HTTPS-only access
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["logging"].arn,
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow ALB service account to write access logs to the designated S3 bucket path 
  statement {
    sid    = "AllowALBAccountPutLogs"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/alb-logs/${var.environment}/AWSLogs/${var.aws_account_id}/*"
    ]
  }
}

# --- Apply Logging Bucket Policy --- #
# Applies the logging bucket policy to the logging bucket
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if key == "logging" && value.enabled
  })

  bucket = aws_s3_bucket.default_region_buckets["logging"].id
  policy = data.aws_iam_policy_document.logging_bucket_policy.json

  depends_on = [
    aws_s3_bucket.default_region_buckets,
    aws_s3_bucket_public_access_block.default_region_bucket_public_access_block,
    aws_s3_bucket_ownership_controls.default_region_bucket_ownership_controls
  ]
}

# --- Module Notes --- #
# General notes for S3 bucket policies and CORS.
#
# 1. Security Policies:
#   - Enforces HTTPS-only access for all buckets (`enforce_https_policy`).
#   - `logging_bucket_policy` relies on HTTPS enforcement from `enforce_https_policy`.
#   - SSE-KMS encryption for data at rest (configured in `s3/main.tf`).
#   - Dynamic policy application to enabled buckets (`for_each` & `merge`).
#
# 2. CORS Configuration:
#   - Conditional config for `wordpress_media` bucket (`enable_cors = true`).
#   - `allowed_origins` - configurable variable, MUST be restricted in production.
#   - `allowed_methods` - GET only (read-only).
#   - `allowed_headers` - Content-Type only (security).
#   - See README/variable docs for CORS security details.
#
# 3. Logging & Compliance:
#   - `logging_bucket_policy`: AWS logging services (`aws:SourceAccount` condition) `s3:PutObject` to `logging` bucket.
#   - `logging_bucket_policy`: `cloudtrail.amazonaws.com` `s3:GetBucketAcl` on `logging` bucket (for CloudTrail).
#   - Logging: ONLY for default region buckets (excluding `logging` bucket) in `aws_s3_bucket_logging`.
#   - Replication bucket logging: intentionally omitted (consider enabling for audit).
#
# 4. Replication:
#   - `replication_destination_policy`: ONLY if replication enabled (`var.replication_region_buckets` defined & enabled buckets).
#   - `replication_destination_policy`: Replication IAM role write access to destination bucket.
#   - Source replication config (IAM Role/Config) in `s3/main.tf`.
#   - Conditional creation using `length(aws_iam_role.replication_role) > 0` (prevents errors if replication disabled).