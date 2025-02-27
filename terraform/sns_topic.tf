# --- SNS Topic for CloudWatch Alarms --- #
resource "aws_sns_topic" "cloudwatch_alarms" {
  name              = "${var.name_prefix}-cloudwatch-alarms"
  kms_master_key_id = module.kms.kms_key_arn # Use the KMS key passed from the KMS module
}

# --- SNS Topic for Replication Region --- #
resource "aws_sns_topic" "replication_region_topic" {
  provider          = aws.replication
  name              = "${var.name_prefix}-replication-region-notifications"
  kms_master_key_id = module.kms.kms_key_arn # Use the KMS key passed from the KMS module
}

# Allow CloudWatch and S3 to publish messages to the topic
resource "aws_sns_topic_policy" "cloudwatch_publish_policy" {
  arn = aws_sns_topic.cloudwatch_alarms.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudWatchToPublish",
        Effect    = "Allow",
        Principal = { Service = "cloudwatch.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.cloudwatch_alarms.arn
      },
      {
        Sid       = "AllowS3ToPublish",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.cloudwatch_alarms.arn
      }
    ]
  })
}

# Allow S3 to publish messages to the replication region topic
resource "aws_sns_topic_policy" "replication_region_publish_policy" {
  provider = aws.replication
  arn      = aws_sns_topic.replication_region_topic.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3ToPublish",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.replication_region_topic.arn
      }
    ]
  })
}

# SNS Subscriptions for all protocols
resource "aws_sns_topic_subscription" "subscriptions" {
  for_each  = { for idx, sub in var.sns_subscriptions : idx => sub }
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}

# SNS Subscriptions for replication region
resource "aws_sns_topic_subscription" "replication_region_subscriptions" {
  provider  = aws.replication
  for_each  = { for idx, sub in var.sns_subscriptions : idx => sub }
  topic_arn = aws_sns_topic.replication_region_topic.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}