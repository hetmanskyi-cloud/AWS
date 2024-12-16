# --- Firehose Delivery Stream --- #
# This resource creates a Firehose delivery stream to process and deliver WAF logs to an S3 bucket.
# - Enabled only in `stage` and `prod` environments to reduce costs during development (`dev`).
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  count       = var.environment != "dev" ? 1 : 0 # Firehose is enabled only in stage and prod.
  name        = "${var.name_prefix}-waf-logs"
  destination = "extended_s3" # Destination is an S3 bucket with extended configuration.

  # --- Extended S3 Configuration --- #
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role[0].arn # IAM Role for Firehose permissions.
    bucket_arn         = var.logging_bucket_arn            # Target S3 bucket for logs.
    prefix             = "${var.name_prefix}/waf-logs/"    # Prefix for organizing WAF logs in the bucket.
    buffering_interval = 300                               # Buffering interval in seconds.
    buffering_size     = 5                                 # Buffering size in MB.
    compression_format = "GZIP"                            # Compress logs in GZIP format for storage efficiency.
    kms_key_arn        = var.kms_key_arn                   # KMS key for encrypting logs.
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-waf-firehose"
    Environment = var.environment
  }
}

# --- IAM Role for Firehose --- #
# This role allows Firehose to write logs to the S3 bucket.
resource "aws_iam_role" "firehose_role" {
  count = var.environment != "dev" ? 1 : 0 # Role is created only in stage and prod.
  name  = "${var.name_prefix}-firehose-role"

  # Policy for assuming the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# --- IAM Policy for Firehose --- #
# This policy defines permissions for Firehose to interact with the S3 bucket.
resource "aws_iam_policy" "firehose_policy" {
  count = var.environment != "dev" ? 1 : 0 # Policy is attached only in stage and prod.
  name  = "${var.name_prefix}-firehose-policy"

  # Policy details.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ],
        Resource = [
          "${var.logging_bucket_arn}/*", # Applies to all objects in the logging bucket.
          var.logging_bucket_arn         # Applies to the bucket itself.
        ]
      }
    ]
  })
}

# --- IAM Role Policy Attachment --- #
# Attaches the IAM policy to the Firehose role.
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  count      = var.environment != "dev" ? 1 : 0 # Attachment is applied only in stage and prod.
  role       = aws_iam_role.firehose_role[0].name
  policy_arn = aws_iam_policy.firehose_policy[0].arn
}

# --- Notes --- #
# 1. Firehose is disabled in dev to avoid unnecessary overhead and storage costs.
# 2. Logs are delivered to an S3 bucket with GZIP compression for storage efficiency.
# 3. S3 is chosen over CloudWatch Logs for its cost-effectiveness and flexibility in long-term storage.
# 4. KMS encryption ensures logs are securely stored in the target bucket.
# 5. The logging bucket is dynamically assigned based on the `logging_bucket_arn` variable.