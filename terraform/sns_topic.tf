# --- SNS Topic for CloudWatch Alarms --- #
# Important:
# - CloudWatch automatically publishes ALARM and OK state changes.
# - Ensure this topic is referenced in all critical alarms.

resource "aws_sns_topic" "cloudwatch_alarms" {
  # Creates an SNS topic in the default region (no 'provider = aws.replication')
  name              = "${var.name_prefix}-cloudwatch-alarms"
  kms_master_key_id = module.kms.kms_key_arn # Use the KMS key passed from the KMS module

  tags = {
    Name        = "${var.name_prefix}-cloudwatch-alarms"
    Environment = var.environment
  }
}

# --- SNS Topic for Replication Region --- #
resource "aws_sns_topic" "replication_region_topic" {
  # Creates an SNS topic in the replication region (provider alias = aws.replication)
  provider          = aws.replication
  name              = "${var.name_prefix}-replication-region-notifications"
  kms_master_key_id = module.kms.kms_key_arn # Use the KMS key passed from the KMS module

  tags = {
    Name        = "${var.name_prefix}-rep-cloudwatch-alarms"
    Environment = var.environment
  }
}

# Policy allowing CloudWatch + S3 to publish to cloudwatch_alarms
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
        Resource  = aws_sns_topic.cloudwatch_alarms.arn,
        # Restrict publishing to only CloudWatch Alarms from this account
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${var.aws_account_id}:alarm:*"
          }
        }
      },
      {
        Sid       = "AllowS3ToPublish",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.cloudwatch_alarms.arn,
        Condition = {
          # Restrict to your AWS account
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# Policy allowing S3 to publish to replication_region_topic
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
        Resource  = aws_sns_topic.replication_region_topic.arn,
        Condition = {
          # Restrict to your AWS account in replication region
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# --- SNS Subscriptions for CloudWatch Alarms --- #
# Note:
# - Email subscriptions require manual confirmation via email link.
# - Use `aws sns list-subscriptions-by-topic` to check status.
# - Unconfirmed subscriptions will cause delivery errors.

# SNS Subscriptions for all protocols
resource "aws_sns_topic_subscription" "subscriptions" {
  for_each  = { for idx, sub in var.sns_subscriptions : idx => sub }
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  depends_on = [aws_sns_topic.cloudwatch_alarms]
}

# SNS Subscriptions for replication region
resource "aws_sns_topic_subscription" "replication_region_subscriptions" {
  provider  = aws.replication
  for_each  = { for idx, sub in var.sns_subscriptions : idx => sub }
  topic_arn = aws_sns_topic.replication_region_topic.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  depends_on = [aws_sns_topic.replication_region_topic]
}

# --- Notes --- #
# 1. Topic Encryption:
#    - Both SNS topics use Customer Managed KMS Keys for encryption at rest.
#    - This enhances control and auditability (module.kms.kms_key_arn).
#
# 2. Publishing Permissions:
#    - CloudWatch Alarms can publish only if they belong to the same AWS account and region.
#    - S3 is allowed to publish (e.g., for replication events) and restricted by SourceAccount.
#
# 3. Email Subscriptions:
#    - Manual confirmation is required for email endpoints.
#    - You can run `aws sns list-subscriptions-by-topic` to verify status.
#
# 4. Multi-Region Support:
#    - Separate topic and policy are created in the replication region via provider alias.
#    - This ensures proper S3 event delivery in cross-region replication setups.
#
# 5. Best Practices:
#    - Use separate topics for replication and default regions to avoid confusion.
#    - Avoid wildcards in SNS policies where not required (e.g., no `*` in actions or resources).
#    - Tag SNS topics for better tracking, billing, and cost allocation.