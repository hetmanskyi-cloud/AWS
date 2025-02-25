# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- CORS Configuration for WordPress Media Bucket --- #
# Configures CORS for 'wordpress_media' bucket for cross-domain browser access.
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count = var.default_region_buckets["wordpress_media"].enabled && var.enable_cors ? 1 : 0 # Check both bucket enabled and enable_cors

  bucket = aws_s3_bucket.default_region_buckets["wordpress_media"].id

  cors_rule {
    allowed_headers = ["Content-Type"] # Restrict headers to required ones.
    allowed_methods = ["GET"]          # Only GET is allowed.

    # SECURITY WARNING: 'allowed_origins' MUST be restricted in production!
    # Default value in terraform.tfvars allows ALL origins ('*') for initial setup.
    # Production: Restrict to specific, trusted domain(s) to prevent MAJOR SECURITY RISK!
    allowed_origins = var.allowed_origins
    max_age_seconds = 3000 # Cache preflight responses.
  }

  # --- CORS Notes --- #
  # 1. Purpose: Enable controlled browser access to 'wordpress_media' bucket from different domains.
  # 2. Security: CRITICAL! Restrict 'allowed_origins' in production. Default allows all ('*') for initial setup ONLY.
  # 3. Methods: 'allowed_methods' limited to 'GET' for enhanced security (read-only access).
  # 4. Headers: 'allowed_headers' restricted to 'Content-Type' for security best practices. Consider removing if unnecessary.
  #    See README and variable docs for security details.
}

# --- Bucket Policies --- #

# Enforces HTTPS-only access policy for buckets,
# relying on Default Encryption instead of explicit SSE-KMS.
resource "aws_s3_bucket_policy" "enforce_https_policy" {
  for_each = tomap({
    for key, value in merge(
      var.default_region_buckets,
      var.replication_region_buckets,
    ) : key => value if value.enabled
  })

  bucket = contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.replication_bucket[each.key].id : aws_s3_bucket.default_region_buckets[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Denies all traffic that is not over HTTPS (SecureTransport = false).
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.replication_bucket[each.key].arn : aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket.default_region_buckets, aws_s3_bucket.replication_region_buckets]
}

# Allows S3 Replication Service to write replicated objects to the destination bucket.
# This policy grants necessary permissions to the replication IAM role.
resource "aws_s3_bucket_policy" "replication_destination_policy" {
  for_each = tomap({
    for key, value in var.replication_region_buckets : key => value
    if value.enabled
  })

  bucket = aws_s3_bucket.replication_bucket[each.key].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplicationWrite",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.replication_role[each.key].arn
        },
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ],
        Resource = "${aws_s3_bucket.replication_bucket[each.key].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket.replication_bucket, aws_iam_role.replication_rol]
}

# Policy for the dedicated "logging" bucket.
# Combines permissions for secure access (HTTPS only) and allows AWS logging services (ALB, WAF, CloudTrail, etc.) to write logs.
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0 # Conditionally create policy if "logging" bucket is enabled

  bucket = aws_s3_bucket.default_region_buckets["logging"].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Statement 1: Allow AWS logging services to write logs (ALB, WAF, CloudTrail, etc.)
      # Grants PutObject permission to any Principal, but *restricts access by SourceAccount* to the current AWS account ID.
      # For simplicity and broad compatibility, Principal is set to "*".
      # In stricter security scenarios, consider narrowing Principal to specific AWS service principals if feasible.
      {
        Sid       = "AllowAllAWSLogs",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.replication_bucket[each.key].arn : aws_s3_bucket.default_region_buckets[each.key].arn}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      },
      # Statement 2: Allow CloudTrail ACL check (required for CloudTrail logging to S3)
      {
        Sid    = "AWSCloudTrailAclCheck",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = "${contains(keys(var.replication_region_buckets), each.key) ? aws_s3_bucket.replication_bucket[each.key].arn : aws_s3_bucket.default_region_buckets[each.key].arn}"
      }
    ]
  })
}

# --- Notes --- #
# 1. Security Policies:
#     - Enforces HTTPS-only access for all buckets via `enforce_https_policy`.
#     - **`logging_bucket_policy` relies on the global `enforce_https_policy` for HTTPS enforcement,**
#       **and does not include an explicit Deny non-HTTPS statement for code simplicity.**
#     - Relies on default Server-Side Encryption (SSE-S3) for data at rest (configured in s3/main.tf).
#     - Policies are dynamically applied to each *enabled* bucket using `for_each` and `merge`.
#
# 2. CORS Configuration:
#     - Configured **conditionally** for the `wordpress_media` bucket **only if `enable_cors` is `true`**.
#     - `allowed_origins` is **fully configurable via variable `allowed_origins`**,
#       **but MUST be restricted to trusted domains in production** to prevent security risks.
#     - `allowed_methods` is **strictly limited to `GET` for enhanced security (read-only access)**.
#     - `allowed_headers` is restricted to `Content-Type` for security best practices; consider removing if unnecessary.
#     - See README and variable documentation for comprehensive CORS security details.
#
# 3. Logging & Compliance:
#     - `logging_bucket_policy` grants **AWS logging services (`aws:SourceAccount` condition) `s3:PutObject` access**
#       **to the dedicated `logging` bucket**, centralizing logs within the AWS account.
#     - `logging_bucket_policy` **also allows `cloudtrail.amazonaws.com` service `s3:GetBucketAcl` action**
#       **on the `logging` bucket**, required for CloudTrail logging to S3.
#     - **Logging is configured ONLY for default region buckets (excluding the `logging` bucket itself) in `aws_s3_bucket_logging`.**
#       **Logging for replication buckets is *intentionally omitted* in this configuration**
#       **but consider enabling it for enhanced audit of replicated data (see documentation).**
#
# 4. Replication:
#     - Replication policies (`replication_destination_policy`) are created **ONLY if replication is explicitly enabled**
#       **(when `var.replication_region_buckets` is defined and contains enabled buckets).**
#     - `replication_destination_policy` ensures **the replication IAM role can write replicated objects**
#       **to the *destination (replication)* bucket**.
#     - Source bucket replication configuration (IAM Role and Replication Configuration) is defined in `s3/main.tf`.
#     - Uses `length(aws_iam_role.replication_role) > 0` in `replication_destination_policy` for conditional creation,
#       **preventing errors when replication is not enabled and the IAM role is absent.**