# --- IAM Role for CloudFront Firehose Delivery Streams (us-east-1) --- #
# This role is required for Kinesis Firehose to deliver CloudFront WAF logs to S3.
# All CloudFront Firehose/IAM resources must be created in us-east-1 (provider = aws.cloudfront).
resource "aws_iam_role" "cloudfront_firehose_role" {
  provider = aws.cloudfront
  count    = var.enable_cloudfront_firehose ? 1 : 0

  name = "${var.name_prefix}-cloudfront-firehose-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-firehose-role-${var.environment}"
  })
}

# --- IAM Policy for CloudFront Firehose Delivery Streams (us-east-1) --- #
# Grants CloudFront Firehose permissions to write logs to the S3 logging bucket and use the KMS key for encryption.
resource "aws_iam_policy" "cloudfront_firehose_policy" {
  provider = aws.cloudfront
  count    = var.enable_cloudfront_firehose ? 1 : 0

  name = "${var.name_prefix}-cloudfront-firehose-policy-${var.environment}"

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
          "${var.logging_bucket_arn}/*",
          var.logging_bucket_arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/*:log-stream:*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-firehose-policy-${var.environment}"
  })
}

# --- IAM Role Policy Attachment (us-east-1, CloudFront) --- #
# Attaches the CloudFront Firehose policy to the Firehose role in us-east-1.
resource "aws_iam_role_policy_attachment" "cloudfront_firehose_policy_attachment" {
  provider   = aws.cloudfront
  count      = var.enable_cloudfront_firehose ? 1 : 0
  role       = aws_iam_role.cloudfront_firehose_role[0].name
  policy_arn = aws_iam_policy.cloudfront_firehose_policy[0].arn
}

# --- Notes --- #
# 1. All CloudFront Firehose IAM resources are created only in us-east-1 via provider = aws.cloudfront.
# 2. No IAM roles or policies for CloudFront Firehose are created in the default region in this module.
# 3. This avoids regional confusion and is required for proper CloudFront WAF logging.
# 4. IAM policy uses least privilege: only required S3/KMS/CloudWatch Logs actions are allowed.
# 5. All resource names and tags use the project and environment naming convention for clarity per environment.