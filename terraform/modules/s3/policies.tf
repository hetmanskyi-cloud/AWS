# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- CORS Configuration for WordPress Media Bucket --- #
# Configures CORS rules for the `wordpress_media` bucket when enabled via the `enable_cors` variable.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count = var.buckets["wordpress_media"].enabled && var.enable_cors ? 1 : 0 # Check both bucket enabled and enable_cors

  bucket = aws_s3_bucket.buckets["wordpress_media"].id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"] # Restrict headers to required ones.
    allowed_methods = ["GET", "POST"]                   # Only GET, POST are allowed.
    allowed_origins = var.allowed_origins               # Initially allow all origins; restrict in prod if needed.
    max_age_seconds = 3000                              # Cache preflight responses.
  }

  # --- Notes --- #
  # Configures CORS for the 'wordpress_media' bucket (if enabled and CORS is enabled).
  # 'allowed_origins' should be restricted in production.
  # Consider further restricting 'allowed_methods'.
}

# --- Bucket Policies --- #

# Bucket Policy to Enforce HTTPS and KMS Encryption
# Ensures that only HTTPS connections are allowed and objects are encrypted with KMS.
resource "aws_s3_bucket_policy" "enforce_https_and_encryption_policy" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
        Condition = {
          StringNotEqualsIfExists = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket.buckets]
}

# Logging Bucket Policy
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  for_each = tomap({
    for key, value in var.buckets : key => value if key == "logging" && value.enabled
  })

  bucket = aws_s3_bucket.buckets["logging"].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLoggingWrite",
        Effect    = "Allow",
        Principal = { Service = "logging.s3.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets["logging"].arn}/*"
      },
      {
        Sid       = "AllowALBLogging",
        Effect    = "Allow",
        Principal = { Service = "elasticloadbalancing.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets["logging"].arn}/alb-logs/*"
      },
      {
        Sid       = "AllowWAFLogging",
        Effect    = "Allow",
        Principal = { Service = "waf.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets["logging"].arn}/waf-logs/*"
      },
      {
        Sid       = "AllowDeliveryLogsWrite",
        Effect    = "Allow",
        Principal = { Service = "delivery.logs.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets["logging"].arn}/alb-logs/*"
      }
    ]
  })
}

# --- CloudTrail Bucket Policy --- #
# Allows CloudTrail to write logs to the logging bucket under the /cloudtrail/ prefix.

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  count = var.buckets["logging"].enabled ? 1 : 0

  bucket = aws_s3_bucket.buckets["logging"].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets["logging"].arn}/cloudtrail/*"
      }
    ]
  })
}

# --- Replication Destination Bucket Policy --- #
# Grants the replication role permissions to write objects to the replication bucket.

resource "aws_s3_bucket_policy" "replication_bucket_policy" {
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) && length(aws_iam_role.replication_role) > 0 ? 1 : 0

  bucket = aws_s3_bucket.buckets["replication"].id

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
# Grants the replication role read access to source buckets for replication.

resource "aws_s3_bucket_policy" "source_bucket_replication_policy" {
  for_each = {
    for key, value in var.buckets : key => value if(
      value.enabled &&
      (value.replication != null ? value.replication : false) &&                        # Для value.replication используем условное выражение
      can(var.buckets["replication"].enabled && var.buckets["replication"].replication) # Для replication используем can()
    )
  }

  bucket = aws_s3_bucket.buckets[each.key].id

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
          aws_s3_bucket.buckets[each.key].arn,
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ]
      }
    ]
  })
}

# --- Notes --- #
# 1. Security Policies:
#    - Enforces HTTPS-only access for all buckets.
#    - Denies unencrypted object uploads (only KMS encryption is allowed).
#    - Policies are dynamically applied to each bucket if enabled.
#
# 2. CORS Configuration:
#    - Configured only for the `wordpress_media` bucket if `enable_cors` is `true`.
#    - `allowed_origins` is configurable but should be restricted in production.
#    - Supports `GET` and `POST` methods only (consider further restrictions if necessary).
#
# 3. Logging & Compliance:
#    - Grants logging service (`logging.s3.amazonaws.com`) write access to the `logging` bucket.
#    - Grants CloudTrail write access to `/cloudtrail/` inside the logging bucket.
#    - Allows ALB, WAF, and delivery logs to be written to specific prefixes.
#
# 4. Replication:
#    - Replication policies are only created if replication is explicitly enabled.
#    - The replication bucket policy ensures objects can be written to the destination.
#    - The source bucket replication policy grants the IAM role read permissions.
#    - Uses `length(aws_iam_role.replication_role) > 0` to prevent errors when the role is absent.