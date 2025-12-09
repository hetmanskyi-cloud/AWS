# --- Bucket Policies, CORS, and Lifecycle Policies for S3 Buckets --- #
# Defines key configurations for security, compliance, and functionality.

# --- WordPress Media Bucket CORS Config --- #
# Configures CORS for 'wordpress_media' bucket.
# - Used for WordPress media file downloads (read-only).
# - Uploads are performed via WordPress backend using signed requests (not public uploads).
resource "aws_s3_bucket_cors_configuration" "wordpress_media_cors" {
  count = try(var.default_region_buckets["wordpress_media"].enabled, false) && var.enable_cors ? 1 : 0 # Conditional CORS config

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
    for key, value in var.default_region_buckets : key => value if value.enabled && key != var.s3_alb_logs_bucket_key && key != var.s3_logging_bucket_key && key != var.s3_cloudtrail_bucket_key && key != "wordpress_media"
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
  count = try(var.default_region_buckets[var.s3_logging_bucket_key].enabled, false) ? 1 : 0

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
      try("${aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].arn}/*", null)
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

      resources = compact([
        try(aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].arn, null),
        try("${aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].arn}/*", null)
      ])

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

    resources = compact([
      try(aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].arn, null),
      try("${aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].arn}/*", null)
    ])

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
  count = try(var.default_region_buckets[var.s3_logging_bucket_key].enabled, false) ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets[var.s3_logging_bucket_key].id
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
  # Create this data source only if the alb_logs bucket is enabled in the variables.
  count = try(var.default_region_buckets[var.s3_alb_logs_bucket_key].enabled, false) ? 1 : 0

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
      try("${aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn}/AWSLogs/${var.aws_account_id}/*", null)
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
      try("${aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn}/AWSLogs/${var.aws_account_id}/*", null)
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
      try(aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn, null)
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
      try(aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn, null)
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

    resources = compact([
      try(aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn, null),
      try("${aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].arn}/*", null)
    ])

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# --- Apply ALB Logs Bucket Policy --- #
resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  count = try(var.default_region_buckets[var.s3_alb_logs_bucket_key].enabled, false) ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets[var.s3_alb_logs_bucket_key].id
  policy = data.aws_iam_policy_document.alb_logs_bucket_policy[0].json

  depends_on = [
    aws_s3_bucket.default_region_buckets,
    aws_s3_bucket_public_access_block.default_region_bucket_public_access_block,
    aws_s3_bucket_ownership_controls.default_region_logging_ownership["alb_logs"],
    data.aws_iam_policy_document.alb_logs_bucket_policy
  ]
}

# --- Unified Policy Document for the WordPress Media Bucket --- #
# This data source constructs a single, comprehensive policy for the wordpress_media bucket.
# It aggregates all necessary permissions into one document to avoid conflicts and ensure
# that a single resource manages the bucket policy.
data "aws_iam_policy_document" "wordpress_media_policy" {
  # This policy is constructed only if the wordpress_media bucket itself is enabled.
  count = try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  # Statement 1: Enforce HTTPS-only access. This is a security best practice.
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.default_region_buckets["wordpress_media"].arn,
      "${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Statement 2: Allow CloudFront OAC Read-Only Access.
  # This block is added dynamically only if CloudFront integration is enabled.
  dynamic "statement" {
    for_each = var.wordpress_media_cloudfront_enabled && var.wordpress_media_cloudfront_distribution_arn != null ? [1] : []
    content {
      sid       = "AllowCloudFrontOACReadOnly"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/*"]
      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [var.wordpress_media_cloudfront_distribution_arn]
      }
    }
  }

  # Statement 3: Allow WordPress EC2 Role to manage media uploads.
  # This block is added dynamically only if the ASG role ARN is provided.
  dynamic "statement" {
    for_each = var.asg_instance_role_arn != null ? [1] : []
    content {
      sid    = "AllowWordPressEC2RoleAccess"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      # Permissions are scoped to the 'uploads' folder for security.
      resources = ["${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/uploads/*"]
      principals {
        type        = "AWS"
        identifiers = [var.asg_instance_role_arn]
      }
    }
  }

  # Statement 4a: Allow Image Processor Lambda to READ original images.
  dynamic "statement" {
    for_each = var.lambda_iam_role_arn != null ? [1] : []
    content {
      sid       = "AllowImageProcessorLambdaRead"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/uploads/*"]
      principals {
        type        = "AWS"
        identifiers = [var.lambda_iam_role_arn]
      }
    }
  }

  # Statement 4b: Allow Image Processor Lambda to WRITE processed images.
  dynamic "statement" {
    for_each = var.lambda_iam_role_arn != null ? [1] : []
    content {
      sid       = "AllowImageProcessorLambdaWrite"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.default_region_buckets["wordpress_media"].arn}/processed/*"]
      principals {
        type        = "AWS"
        identifiers = [var.lambda_iam_role_arn]
      }
    }
  }
}

# --- Apply the Unified Policy to the WordPress Media Bucket --- #
# This single resource applies the comprehensive policy constructed above.
resource "aws_s3_bucket_policy" "wordpress_media_policy" {
  count = try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  bucket = aws_s3_bucket.default_region_buckets["wordpress_media"].id
  policy = data.aws_iam_policy_document.wordpress_media_policy[0].json

  depends_on = [
    # Ensure the policy document is fully rendered before attempting to apply it.
    data.aws_iam_policy_document.wordpress_media_policy
  ]
}

# --- Notes --- #
# 1. WordPress Media Bucket CORS Config:
#    - CORS for 'wordpress_media' bucket.
#    - Allows GET method, Content-Type header only.
#    - **Restrict 'allowed_origins' in production (CRITICAL security).**
#
# 2. Enforce HTTPS Policy (Default Region Buckets):
#    - HTTPS enforcement for default region buckets, **excluding '${var.s3_wordpress_media_bucket_key}', '${var.s3_logging_bucket_key}', '${var.s3_alb_logs_bucket_key}', '${var.s3_cloudtrail_bucket_key}', which have dedicated policies.**
#    - Denies HTTP access to bucket and objects.
#
# 3. Unified Replication Destination Bucket Policy:
#    - HTTPS enforcement and replication permissions for replication region buckets.
#    - Grants replication role permissions (ReplicateObject, etc.) on destination bucket.
#
# 4. ALB Logs Bucket Permissions (IAM Policy Document):
#    - Permissions for ALB to write logs to '${var.s3_alb_logs_bucket_key}' bucket.
#    - Permits **'delivery.logs.amazonaws.com' service principal and regional ELB account** (via data source) for GetBucketAcl/PutObject.
#    - Condition: s3:x-amz-acl = "bucket-owner-full-control".
#    - Enforces HTTPS-only access.
#
# 5. Bucket Policy Application Summary:
#    - **Unified '${var.s3_wordpress_media_bucket_key}' policy:** Applied exclusively to the '${var.s3_wordpress_media_bucket_key}' bucket, granting granular access to CloudFront, the EC2 Role, and the image processor Lambda.
#    - **Dedicated Logging policy:** Applied exclusively to the '${var.s3_logging_bucket_key}' bucket (allows S3 log delivery & enforces HTTPS).
#    - **Dedicated ALB logs policy:** Applied exclusively to the '${var.s3_alb_logs_bucket_key}' bucket.
#    - **Generic HTTPS-Only policy:** Applied to remaining general-purpose buckets.
#    - **Replication Destination policy:** Applied to replication region buckets.
#
# 6. Security Best Practices:
#    - Encryption for logging buckets: '${var.s3_logging_bucket_key}' uses SSE-KMS, '${var.s3_alb_logs_bucket_key}' uses SSE-S3 (AES256).
#    - Versioning: enabled where object history is needed.
#    - Public Access Block: configured for all buckets (prevent public access).
#    - **Access control primarily relies on IAM and Bucket Policies, leveraging 'BucketOwnerEnforced' where applicable.**
#
# 7. CloudTrail Bucket Policy:
#    - **Policy for ${var.s3_cloudtrail_bucket_key} bucket is *not defined in this `s3/policies.tf` file*.**
#    - **It is defined in `cloudtrail.tf` of the *main module*.**
#
# 8. WordPress Media Bucket CORS Configuration Details:
#    - Enables controlled cross-origin access to '${var.s3_wordpress_media_bucket_key}' bucket.
#    - Allows only GET requests with 'Content-Type' header.
#    - **Important:** 'allowed_origins' must be properly restricted in production for security.
#
# 9. ${var.s3_scripts_bucket_key} Bucket:
#    - No dedicated bucket policy defined in this file.
#    - Access is managed via IAM roles attached to EC2 instances.
#
# 10. CloudFront Logging Policy:
#    - The **unified ${var.s3_logging_bucket_key} bucket policy** includes a statement that grants the 'delivery.logs.amazonaws.com'
#      service principal permissions to write CloudFront v2 real-time logs.
