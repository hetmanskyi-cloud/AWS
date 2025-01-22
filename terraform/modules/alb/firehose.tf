# --- Firehose Delivery Stream --- #
# This resource creates a Firehose delivery stream to process and deliver WAF logs to an S3 bucket.
# Controlled by the `enable_firehose` variable to enable or disable all related resources.
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  count = var.enable_firehose ? 1 : 0

  name        = "${var.name_prefix}-waf-logs"
  destination = "extended_s3" # Destination is an S3 bucket with extended configuration.

  # --- Extended S3 Configuration --- #
  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role[0].arn # IAM Role for Firehose permissions.
    bucket_arn = var.logging_bucket_arn            # Target S3 bucket for logs.
    prefix     = "${var.name_prefix}/waf-logs/"    # Prefix for organizing WAF logs in the bucket.

    # These buffering settings represent a default configuration suitable for testing. 
    # For production, these values should be adjusted based on anticipated log volume and delivery latency requirements.
    buffering_interval = 300 # Buffering interval in seconds.
    buffering_size     = 5   # Buffering size in MB.

    # GZIP compression reduces storage costs but may increase processing costs when decrypting data in the future.
    compression_format = "GZIP" # Compress logs in GZIP format for storage efficiency.

    kms_key_arn = var.kms_key_arn # KMS key for encrypting logs. In production replace with CMK
  }
}

# --- IAM Role for Firehose --- #
# This IAM Role is specifically required for delivering logs from Firehose to the target S3 bucket.
# Ensure this role has permissions only for the required actions to follow the principle of least privilege.
resource "aws_iam_role" "firehose_role" {
  count = var.enable_firehose ? 1 : 0

  name = "${var.name_prefix}-firehose-role"

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
# This policy defines the permissions required by Firehose to interact with the S3 bucket.
resource "aws_iam_policy" "firehose_policy" {
  count = var.enable_firehose ? 1 : 0

  name = "${var.name_prefix}-firehose-policy"

  # Policy details.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ],
        Resource = [
          "${var.logging_bucket_arn}/*", # Applies to all objects in the logging bucket.
          var.logging_bucket_arn         # Applies to the bucket itself.
        ]
      },
      { # Permission to encrypt using KMS
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}

# --- IAM Role Policy Attachment --- #
# Attaches the IAM policy to the Firehose role.
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  count = var.enable_firehose ? 1 : 0

  role       = aws_iam_role.firehose_role[0].name
  policy_arn = aws_iam_policy.firehose_policy[0].arn
}

# --- Notes --- #

# 1. All Firehose-related resources are controlled by the `enable_firehose` variable.
# 2. Logs are delivered to an S3 bucket with GZIP compression for storage efficiency.
# 3. S3 is chosen over CloudWatch Logs for its cost-effectiveness and flexibility in long-term storage.
#    For small projects, this is the optimal solution. If the project scales, consider CloudWatch Logs
#    for real-time monitoring, but be mindful of the additional costs.
# 4. KMS encryption ensures logs are securely stored in the target bucket.
# 5. The logging bucket is dynamically assigned based on the logging_bucket_arn variable.