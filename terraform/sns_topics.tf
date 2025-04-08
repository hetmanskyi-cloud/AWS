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
  # Only create if replication is enabled for wordpress_media bucket
  count = var.replication_region_buckets["wordpress_media"].enabled ? 1 : 0

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
  count = var.replication_region_buckets["wordpress_media"].enabled ? 1 : 0

  provider = aws.replication
  arn      = aws_sns_topic.replication_region_topic[0].arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3ToPublish",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.replication_region_topic[0].arn,
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

# --- SNS Subscriptions for replication region --- #
resource "aws_sns_topic_subscription" "replication_region_subscriptions" {
  for_each = var.replication_region_buckets["wordpress_media"].enabled ? { for idx, sub in var.sns_subscriptions : idx => sub } : {}

  provider  = aws.replication
  topic_arn = aws_sns_topic.replication_region_topic[0].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  depends_on = [aws_sns_topic.replication_region_topic]
}

# --- SNS Topic for CloudTrail Events --- #
# Purpose:
# - Used by AWS CloudTrail to publish events related to API activity.
# - Enables real-time security alerts (e.g., role creation, unauthorized access attempts).
# - Same subscribers as for CloudWatch alarms (via var.sns_subscriptions).
resource "aws_sns_topic" "cloudtrail_events" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0 # Only create if cloudtrail is enabled

  name              = "${var.name_prefix}-cloudtrail-events"
  kms_master_key_id = module.kms.kms_key_arn # Use CMK for encryption at rest

  tags = {
    Name        = "${var.name_prefix}-cloudtrail-events"
    Environment = var.environment
  }
}

# --- SNS Topic Policy --- #
# Allows CloudTrail service to publish messages to the SNS topic.
resource "aws_sns_topic_policy" "cloudtrail_events_policy" {
  count = var.default_region_buckets["cloudtrail"].enabled ? 1 : 0 # Only create if cloudtrail is enabled

  arn = aws_sns_topic.cloudtrail_events[0].arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudTrailToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail_events[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# --- SNS Subscriptions for CloudTrail Events --- #
# Subscribes same endpoints as used for CloudWatch alarms.
# Manual email confirmation is still required for email protocols.
resource "aws_sns_topic_subscription" "cloudtrail_subscriptions" {
  for_each = var.default_region_buckets["cloudtrail"].enabled ? { for idx, sub in var.sns_subscriptions : idx => sub } : {}

  topic_arn = aws_sns_topic.cloudtrail_events[0].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  depends_on = [aws_sns_topic.cloudtrail_events]
}

# --- Notes --- #
# 1. Topic Encryption:
#    - All SNS topics use Customer Managed KMS Keys (module.kms.kms_key_arn).
#    - This ensures encryption at rest with full control and auditability.

# 2. Publishing Permissions:
#    - CloudWatch Alarms can publish only from the same AWS account and region.
#    - S3 can publish to replication-related topics, restricted by SourceAccount.
#    - CloudTrail is allowed to publish to the cloudtrail-events topic (via dedicated policy).

# 3. Email Subscriptions:
#    - Manual confirmation is required for email endpoints.
#    - Run `aws sns list-subscriptions-by-topic` to verify the status of subscriptions.

# 4. Multi-Region Support:
#    - Replication-specific topics and policies are created using provider alias `aws.replication`.
#    - This ensures correct S3 event delivery during cross-region replication.

# 5. Conditional Topic Creation:
#    - SNS topics for CloudWatch Alarms are always created.
#    - SNS topics for CloudTrail events and replication region are only created if the corresponding features
#      (CloudTrail logging or replication) are enabled in the configuration.
#    - This ensures that resources are only created when necessary, avoiding unused topics.

# 6. Best Practices:
#    - Use separate topics for CloudWatch, CloudTrail, and replication events for clarity.
#    - Avoid wildcard actions or resources in SNS policies unless explicitly required.
#    - Tag all SNS topics consistently for cost allocation and resource tracking.