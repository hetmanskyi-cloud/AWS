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
    for key, value in var.default_region_buckets : key => value if value.enabled && key != "alb_logs" && key != "logging" && key != "cloudtrail" && key != "wordpress_media"
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

# --- Unified Policy Document for the S3 Logging Bucket --- #
# This data source constructs a single, comprehensive policy for the 'logging' bucket.
# It aggregates all required permissions into one document to avoid conflicts and ensure
# that a single resource manages the bucket policy.
data "aws_iam_policy_document" "unified_logging_bucket_policy" {
  # This policy is constructed only if the logging bucket itself is enabled.
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  # Statement 1: Allow S3 Server Access Logs to write to this bucket.
  # This is required for other S3 buckets to deliver their own access logs here.
  statement {
    sid     = "AllowS3ServerAccessLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    resources = [
      "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
    ]

    # This condition ensures the bucket owner gets full control over the delivered log objects.
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # Statement 2: Allow CloudFront Access Logs v2 (via CloudWatch Log Delivery) to write to this bucket.
  # This is for the modern CloudFront access logging method for Real-time Logs.
  dynamic "statement" {
    for_each = var.enable_cloudfront_standard_logging_v2 ? [1] : []
    content {
      sid    = "AllowCloudFrontAccessLogsV2"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:GetBucketAcl" # Required by the delivery service for validation.
      ]
      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      resources = [
        aws_s3_bucket.default_region_buckets["logging"].arn,
        "${aws_s3_bucket.default_region_buckets["logging"].arn}/*"
      ]

      # This security condition restricts access to delivery services originating from your AWS account.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [var.aws_account_id]
      }
    }
  }

  # Statement 3: Enforce HTTPS-only access by denying all insecure (HTTP) requests.
  # This is a security best practice for all buckets.
  statement {
    sid     = "EnforceHTTPSOnly"
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
}

# --- Apply the Unified Policy to the Logging Bucket --- #
# This single resource applies the comprehensive policy constructed above,
# acting as the sole source of truth for the logging bucket's policy.
resource "aws_s3_bucket_policy" "unified_logging_bucket_policy" {
  count = var.default_region_buckets["logging"].enabled ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets["logging"].id
  policy = data.aws_iam_policy_document.unified_logging_bucket_policy[0].json

  depends_on = [
    # Ensure the policy document is fully rendered before attempting to apply it.
    data.aws_iam_policy_document.unified_logging_bucket_policy
  ]
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
    aws_s3_bucket_ownership_controls.default_region_logging_ownership["alb_logs"],
    data.aws_iam_policy_document.alb_logs_bucket_policy
  ]
}

# --- WordPress Media Bucket Policy for CloudFront OAC and EC2 Role Uploads --- #
# Grants CloudFront distribution (via Origin Access Control) read-only access
# and the WordPress EC2 Role write access for media uploads.
# This policy is the single source of truth for all permissions on this bucket.
resource "aws_s3_bucket_policy" "wordpress_media_cloudfront_policy" {
  # This policy is applied only if the 'wordpress_media' bucket is enabled
  # AND the CloudFront distribution for it is also enabled.
  count = var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets["wordpress_media"].id # Target bucket for the policy

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      # Statement 1: Enforce HTTPS Only
      # Denies any requests to the bucket that do not use HTTPS.
      [
        {
          Sid       = "DenyInsecureTransport",
          Effect    = "Deny",
          Principal = { "AWS" : "*" },
          Action    = "s3:*",
          Resource = [
            "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}",
            "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*",
          ],
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        }
      ],
      # Statement 2: Allow CloudFront OAC Read-Only Access
      # This statement is included only if CloudFront integration is enabled
      # AND the CloudFront Distribution ARN is known (not null).
      # It grants CloudFront permission to retrieve objects from the bucket.
      (var.wordpress_media_cloudfront_enabled && var.wordpress_media_cloudfront_distribution_arn != null) ? [
        {
          Sid    = "AllowCloudFrontOACReadOnly",
          Effect = "Allow",
          Principal = {
            Service = "cloudfront.amazonaws.com"
          },
          Action = [
            "s3:GetObject",
          ],
          Resource = "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*",
          Condition = {
            StringEquals = {
              "AWS:SourceArn" = var.wordpress_media_cloudfront_distribution_arn
            }
          }
        }
      ] : [], # If CloudFront is not enabled OR ARN is null, this statement list will be empty

      # Statement 3: Allow WordPress (via ASG EC2 Instance Role) to UPLOAD and SET ACLs for media files.
      # This is conditional on the EC2 role ARN being provided.
      # The condition prevents uploads from being made public at the S3 level.
      (var.asg_instance_role_arn != null) ? [
        {
          Sid    = "AllowWordPressEC2RoleUploads",
          Effect = "Allow",
          Principal = {
            AWS = var.asg_instance_role_arn # ARN of the IAM role from the ASG module
          },
          Action = [
            "s3:PutObject",
            "s3:PutObjectAcl" # Allow setting ACLs for uploaded objects
          ],
          Resource = "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*",
          Condition = {
            StringNotEquals = {
              "s3:x-amz-acl" = "public-read" # Prevent public read access
            }
          }
        }
      ] : [], # If the EC2 role ARN is null, this statement list will be empty

      # Statement 4: Allow WordPress (via ASG EC2 Instance Role) to READ and DELETE media files.
      # These actions do not support the s3:x-amz-acl condition key, so they are in a separate statement.
      (var.asg_instance_role_arn != null) ? [
        {
          Sid    = "AllowWordPressEC2RoleReadDelete",
          Effect = "Allow",
          Principal = {
            AWS = var.asg_instance_role_arn # ARN of the IAM role from the ASG module
          },
          Action = [
            "s3:GetObject",
            "s3:DeleteObject" # Allow deleting media files
          ],
          Resource = "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*"
        }
      ] : [] # If the EC2 role ARN is null, this statement list will be empty
    )
  })

  # Explicitly depends on the S3 bucket creation to ensure the bucket exists before policy application.
  depends_on = [
    aws_s3_bucket.default_region_buckets,
  ]
}

# --- Notes --- #
# 1. WordPress Media Bucket CORS Config:
#    - CORS for 'wordpress_media' bucket.
#    - Allows GET method, Content-Type header only.
#    - **Restrict 'allowed_origins' in production (CRITICAL security).**
#
# 2. Enforce HTTPS Policy (Default Region Buckets):
#    - HTTPS enforcement for default region buckets, **excluding 'logging', 'alb_logs', 'cloudtrail'.**
#    - Denies HTTP access to bucket and objects.
#
# 3. Unified Replication Destination Bucket Policy:
#    - HTTPS enforcement and replication permissions for replication region buckets.
#    - Grants replication role permissions (ReplicateObject, etc.) on destination bucket.
#
# 4. ALB Logs Bucket Permissions (IAM Policy Document):
#    - Permissions for ALB to write logs to 'alb_logs' bucket.
#    - Permits **'delivery.logs.amazonaws.com' service principal and regional ELB account** (via data source) for GetBucketAcl/PutObject.
#    - Condition: s3:x-amz-acl = "bucket-owner-full-control".
#    - Enforces HTTPS-only access.
#    - **Note: No separate statement for S3 Server Access Logs (not relevant for ALB logs bucket).***
#
# 5. Bucket Policy Application Summary:
#    - Default HTTPS policy: applied to default region buckets **except 'alb_logs', 'logging', 'cloudtrail'.**
#    - Dedicated Logging policy: applied exclusively to 'logging' bucket (allows S3 log delivery & enforces HTTPS).
#    - Dedicated ALB logs policy: applied exclusively to 'alb_logs' bucket.
#    - Replication Destination policy: applied to replication region buckets.
#
# 6. Security Best Practices:
#    - Encryption for logging buckets: 'logging' uses SSE-KMS, 'alb_logs' uses SSE-S3 (AES256).
#    - Versioning: enabled where object history is needed.
#    - Public Access Block: configured for all buckets (prevent public access).
#    - **Access control primarily relies on IAM and Bucket Policies, leveraging 'BucketOwnerEnforced' where applicable.**
#
# 7. CloudTrail Bucket Policy:
#    - **Policy for CloudTrail bucket is *not defined in this `s3/policies.tf` file*.**
#    - **It is defined in `cloudtrail.tf` of the *main module*.**
#    - **Refer to the `cloudtrail.tf` file in the main module for CloudTrail bucket policy details.**
#
# 8. WordPress Media Bucket CORS Configuration Details:
#    - Enables controlled cross-origin access to 'wordpress_media' bucket.
#    - Allows only GET requests with 'Content-Type' header.
#    - **Important:** 'allowed_origins' must be properly restricted in production for security.
#
# 9. Scripts Bucket:
#    - No dedicated bucket policy defined in this file.
#    - Access is managed via IAM roles attached to EC2 instances.
#    - Scripts are downloaded by EC2 using instance profile permissions.
#
# 10. CloudFront Logging Policy:
#     - A dedicated bucket policy 'cloudfront_logging_policy' is added to the 'logging' S3 bucket.
#     - This policy explicitly grants 'cloudfront.amazonaws.com' service principal
#       permissions to write objects (`s3:PutObject`) with `bucket-owner-full-control` ACL
#       and optionally read the bucket ACL (`s3:GetBucketAcl`) for validation purposes.
#     - The resource path is restricted to the 'cloudfront-media-logs/*' prefix within the logging bucket.