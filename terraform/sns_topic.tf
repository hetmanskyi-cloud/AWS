# --- SNS Topic for CloudWatch Alarms --- #
resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.name_prefix}-cloudwatch-alarms"
}

# Allow CloudWatch to publish messages to the topic
resource "aws_sns_topic_policy" "cloudwatch_publish_policy" {
  arn = aws_sns_topic.cloudwatch_alarms.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "cloudwatch.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.cloudwatch_alarms.arn
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
