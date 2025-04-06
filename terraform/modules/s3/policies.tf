# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- WordPress Media Bucket CORS Config --- #
# Configures CORS for 'wordpress_media' bucket.
# - Used for WordPress media file downloads (read-only).
# - Uploads are performed via WordPress backend using signed requests (not public uploads).
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

  # CORS Notes:
  # 1. Purpose: Browser access to 'wordpress_media' bucket.
  # 2. Security: CRITICAL! Restrict 'allowed_origins' in production!
  # 3. Methods: GET only (read-only).
  # 4. Headers: Content-Type only (security best practice).
}

# --- Enforce HTTPS Policy for Default Region Buckets --- #
# These buckets ('logging', 'alb_logs', 'cloudtrail') have dedicated policies or different access mechanisms.
resource "aws_s3_bucket_policy" "default_region_enforce_https_policy" {
  # HTTPS policy for default region buckets (EXCLUDING Logging, ALB Logs and CloudTrail)
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value if value.enabled && key != "alb_logs" && key != "logging" && key != "cloudtrail"
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
        Resource = [
          aws_s3_bucket.default_region_buckets[each.key].arn,
          "${aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        ]
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

# --- Logging Bucket Policy (Allow Log Delivery & Enforce HTTPS) --- #
# This policy allows AWS S3 Server Access Logs (`logging.s3.amazonaws.com`) to write logs
# to the logging bucket (`logging`). It also enforces HTTPS by denying insecure (HTTP) connections.
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  count  = var.default_region_buckets["logging"].enabled ? 1 : 0
  bucket = aws_s3_bucket.default_region_buckets["logging"].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Allow AWS S3 Server Access Logs service to write logs to this bucket
      {
        Sid    = "AllowS3ServerAccessLogs"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # Enforce HTTPS-only access: deny any requests using insecure HTTP
      {
        Sid       = "EnforceHTTPSOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.default_region_buckets["logging"].arn,
          "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket.default_region_buckets]
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
          AWS = try(aws_iam_role.replication_role[0].arn, "")
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

# Retrieve AWS ALB service account ARN for the specified region
data "aws_elb_service_account" "main" {
  region = var.aws_region
}

# --- IAM Policy Document for ALB Logs Bucket Permissions --- #
data "aws_iam_policy_document" "alb_logs_bucket_policy" {
  count = var.default_region_buckets["alb_logs"].enabled ? 1 : 0 # Conditional data source

  # Statement 1: AWSLogDeliveryWrite - Service principal
  # Grants the ALB service "delivery.logs.amazonaws.com" permission to PutObject
  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["alb_logs"].arn}/AWSLogs/${var.aws_account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Statement 2: AWSLogDeliveryWrite - Regional ELB account
  # Grants the regional ELB account (e.g. arn:aws:iam::156460612806:root) permission to PutObject
  statement {
    sid     = "AWSLogDeliveryWriteRegional"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["alb_logs"].arn}/AWSLogs/${var.aws_account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Statement 3: AWSLogDeliveryAclCheck - Service principal
  # Allows "delivery.logs.amazonaws.com" to read the bucket ACL (validation).
  statement {
    sid     = "AWSLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["alb_logs"].arn
    ]
  }

  # Statement 4: AWSLogDeliveryAclCheck - Regional ELB account
  statement {
    sid     = "AWSLogDeliveryAclCheckRegional"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["alb_logs"].arn
    ]
  }

  # Statement 5 (Optional): DenyInsecureTransport (HTTPS Enforcement)
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.default_region_buckets["alb_logs"].arn,
      "${aws_s3_bucket.default_region_buckets["alb_logs"].arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# --- Apply ALB Logs Bucket Policy --- #
resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  count = var.default_region_buckets["alb_logs"].enabled ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets["alb_logs"].id
  policy = data.aws_iam_policy_document.alb_logs_bucket_policy[0].json

  depends_on = [
    aws_s3_bucket.default_region_buckets,
    aws_s3_bucket_public_access_block.default_region_bucket_public_access_block,
    aws_s3_bucket_ownership_controls.default_region_bucket_ownership_controls,
    data.aws_iam_policy_document.alb_logs_bucket_policy
  ]
}

# --- Notes --- #
# 1. WordPress Media Bucket CORS Config:
#    - CORS for 'wordpress_media' bucket.
#    - Allows GET method, Content-Type header only.
#    - **Restrict 'allowed_origins' in production (CRITICAL security).**
#
# 2. Enforce HTTPS Policy (Default Region Buckets):
#    - HTTPS enforcement for default region buckets, **excluding 'logging', 'alb_logs', 'cloudtrail'.**
#    - Denies HTTP access to bucket and objects.
#
# 3. Unified Replication Destination Bucket Policy:
#    - HTTPS enforcement and replication permissions for replication region buckets.
#    - Grants replication role permissions (ReplicateObject, etc.) on destination bucket.
#
# 4. ALB Logs Bucket Permissions (IAM Policy Document):
#    - Permissions for ALB to write logs to 'alb_logs' bucket.
#    - Permits **'delivery.logs.amazonaws.com' service principal and regional ELB account** (via data source) for GetBucketAcl/PutObject.
#    - Condition: s3:x-amz-acl = "bucket-owner-full-control".
#    - Enforces HTTPS-only access.
#    - **Note: No separate statement for S3 Server Access Logs (not relevant for ALB logs bucket).***
#
# 5. Bucket Policy Application:
#    - Default HTTPS policy: applied to default region buckets **except 'alb_logs', 'logging', 'cloudtrail'.**
#    - Dedicated ALB logs policy: applied exclusively to 'alb_logs' bucket.
#
# 6. Security Best Practices:
#    - Logging buckets ('logging', 'alb_logs'): SSE-S3 (AES256) encryption.
#    - Versioning: enabled where object history is needed.
#    - Public Access Block: configured for all buckets (prevent public access).
#
# 7. **CloudTrail Bucket Policy: **
#   - **Policy for CloudTrail bucket is *not defined in this `s3/policies.tf` file*.**
#   - **It is defined in `cloudtrail.tf` of the *main module*.
#   - **Refer to the `cloudtrail.tf` file in the main module for CloudTrail bucket policy details.**
#
# 8. WordPress Media Bucket CORS Configuration:
#    - Enables controlled cross-origin access to 'wordpress_media' bucket.
#    - Allows only GET requests with 'Content-Type' header.
#    - **Important:** 'allowed_origins' must be properly restricted in production for security.
# 9. Scripts Bucket:
#    - No dedicated bucket policy required.
#    - Access is managed via IAM roles attached to EC2 instances.
#    - Scripts are downloaded by EC2 using instance profile permissions.