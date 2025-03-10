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

# --- Module Notes --- #
#
# 1. WordPress Media Bucket CORS Config:
#    - Configures CORS for the 'wordpress_media' bucket.
#    - Allows only GET method and the Content-Type header.
#    - 'allowed_origins' must be restricted in production.
#
# 2. Enforce HTTPS Policy for Default Region Buckets:
#    - Applies an HTTPS enforcement policy to all default region buckets, including the 'logging' bucket,
#      and excluding only the 'alb_logs' bucket.
#    - Denies any S3 actions if aws:SecureTransport is false for both the bucket and its objects.
#
# 3. Unified Replication Destination Bucket Policy:
#    - Combines HTTPS enforcement with replication permissions for replication region buckets.
#    - Grants the replication role permissions (ReplicateObject, ReplicateDelete, ReplicateTags,
#      PutObject, and PutObjectAcl) on the destination bucket.
#
# 4. IAM Policy Document for ALB Logs Bucket Permissions:
#    - Defines permissions specifically required for Application Load Balancer (ALB) to write access logs into the 'alb_logs' bucket.
#    - Permits the service 'elasticloadbalancing.amazonaws.com' to perform s3:GetBucketAcl and s3:PutObject,
#      conditioned on s3:x-amz-acl being "bucket-owner-full-control".
#    - Allows the ALB service account (retrieved via data.aws_alb_service_account) to write logs.
#    - Enforces HTTPS-only access for all principals accessing the bucket.
#    - **Note:** Statement for S3 Log Delivery (logging.s3.amazonaws.com) has been removed as it's not relevant to the ALB logs bucket policy.
#
# 5. Application of Bucket Policies:
#    - The default HTTPS enforcement policy is applied to all default region buckets except 'alb_logs'.
#    - A separate, more detailed policy (with ELB log permissions) is applied exclusively to the 'alb_logs' bucket.
#
# 6. Security Best Practices:
#    - For logging purposes, both the 'logging' and 'alb_logs' buckets use SSE-S3 (AES256) encryption.
#    - Versioning is enabled for buckets where needed to maintain object history.
#    - Public Access Block is configured for all buckets to prevent unauthorized public access.