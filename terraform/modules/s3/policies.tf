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

# Enforce HTTPS Policy
resource "aws_s3_bucket_policy" "enforce_https_policy" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.buckets[each.key].arn,
          "${aws_s3_bucket.buckets[each.key].arn}/*"
        ]
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
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? 1 : 0

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

# --- Bucket Policy to Enforce Encryption --- #
# Ensures that only encrypted objects can be uploaded to the selected buckets.

resource "aws_s3_bucket_policy" "enforce_encryption" {
  for_each = tomap({
    for key, value in var.buckets : key => value if value.enabled
  })

  bucket = aws_s3_bucket.buckets[each.key].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*",
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# --- Notes --- #
# 1. Security Policies:
#    - Enforces HTTPS-only access.
#    - Grants replication role write access to the replication bucket.
#    - Grants replication role read access to source buckets (for replication).
#    - Enforces server-side encryption for all buckets.
# 2. CORS Configuration:
#    - Configured for the 'wordpress_media' bucket (if enabled and CORS is enabled).
#    - 'allowed_origins' should be restricted in production.
# 3. Dynamic Configuration:
#    - Buckets are managed via 'var.buckets' in terraform.tfvars.
#    - Policies are dynamically applied based on bucket configuration.
# 4. Logging Configuration:
#    - Grants logging service write access to the logging bucket.
#    - Grants CloudTrail write access to the logging bucket (under /cloudtrail/ prefix).
# 5. Replication:
#    - Policies for replication are created only if replication is enabled.
#    - Ensure source and destination buckets exist and are configured.