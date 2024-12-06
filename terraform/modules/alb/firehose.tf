# Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "${var.name_prefix}-waf-logs"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = var.logging_bucket_arn
    buffering_interval = 300
    buffering_size     = 5
    compression_format = "GZIP"
  }

  tags = {
    Name        = "${var.name_prefix}-waf-firehose"
    Environment = var.environment
  }
}

# IAM Role for Firehose
resource "aws_iam_role" "firehose_role" {
  name = "${var.name_prefix}-firehose-role"

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

resource "aws_iam_policy" "firehose_policy" {
  name = "${var.name_prefix}-firehose-policy"
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
          "${var.logging_bucket_arn}/*",
          var.logging_bucket_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}
