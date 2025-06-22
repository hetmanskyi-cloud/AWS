# --- CloudFront Metric Alarms (us-east-1) --- #
# This file defines CloudWatch Alarms for key CloudFront metrics
# to ensure performance and reliability monitoring.
# All alarms for CloudFront metrics must be created in us-east-1.

resource "aws_cloudwatch_metric_alarm" "cloudfront_error_rate" {
  provider = aws.cloudfront # Alarms for CloudFront must be in us-east-1

  # Create alarm only if the distribution is enabled and an SNS topic ARN is provided.
  count = local.enable_cloudfront_media_distribution && var.enable_cloudfront_waf ? 1 : 0

  alarm_name          = "${var.name_prefix}-cloudfront-high-error-rate-${var.environment}"
  alarm_description   = "Alarm triggers if CloudFront 4xx/5xx error rate exceeds 5% for 5 minutes. This indicates potential issues with content availability or origin health."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5   # Threshold in percent
  period              = 300 # Period in seconds (5 minutes)
  statistic           = "Average"

  # Metric details for CloudFront
  namespace   = "AWS/CloudFront"
  metric_name = "TotalErrorRate" # Monitors the percentage of both 4xx and 5xx errors

  dimensions = {
    DistributionId = aws_cloudfront_distribution.wordpress_media[0].id
    Region         = "Global" # CloudFront metrics are in the "Global" dimension
  }

  # Actions to take when the alarm state is reached
  actions_enabled = true
  alarm_actions   = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : [] # Sends a notification to the central SNS topic
  ok_actions      = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : [] # Optional: Sends a notification when the state returns to OK
}

# --- Notes --- #
# 1. Scope and Region:
#    - This alarm monitors a global CloudFront metric, so it must be created in the 'us-east-1' region (via provider = aws.cloudfront).
#    - The 'Region' dimension for the metric must be set to 'Global'.
#
# 2. Key Metric (TotalErrorRate):
#    - We monitor 'TotalErrorRate', which combines both 4xx (client-side) and 5xx (server-side) errors as a percentage of total requests.
#    - A spike in this metric is a strong indicator of user-facing issues, such as broken links (404), permission problems (403), or origin failures (5xx).
#
# 3. SNS Integration:
#    - The alarm's notification is sent to the SNS topic ARN passed in via 'var.sns_alarm_topic_arn'.
#    - CRITICAL: The policy of the target SNS topic must explicitly allow CloudWatch Alarms from the 'us-east-1' region to publish messages. See root module 'sns_topics.tf' for this configuration.
#
# 4. Extensibility:
#    - For enhanced monitoring, you could add another alarm for 'CacheHitRate' (as a 'LessThanThreshold' type)
#      to detect performance and cost optimization issues.
