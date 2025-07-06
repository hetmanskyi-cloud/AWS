# --- CloudWatch Alarm for DLQ --- #

# This alarm triggers if any messages land in a Dead Letter Queue,
# indicating a persistent failure in message processing that requires manual investigation.
resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  # This alarm is created for every DLQ defined in this module.
  # The module itself is conditional, so no extra 'count' or 'for_each' logic is needed here.
  for_each = aws_sqs_queue.dlq

  # Naming and Description
  alarm_name        = "${var.name_prefix}-${each.value.name}-messages-visible-alarm-${var.environment}"
  alarm_description = "Alarm that triggers when there are messages in the DLQ for ${each.value.name}, indicating processing failures."

  # Alarm Threshold Configuration
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1 # Trigger if even one message is visible

  # Metric Definition
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  statistic   = "Sum"
  period      = 300 # Check every 5 minutes

  dimensions = {
    QueueName = each.value.name
  }

  # Notification Actions
  alarm_actions = [var.cloudwatch_alarms_topic_arn]
  ok_actions    = [var.cloudwatch_alarms_topic_arn] # Notify when the queue is clear again

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-messages-visible-alarm-${var.environment}"
  })
}

# --- Notes --- #
# 1. Critical Failure Alert: The alarm on `ApproximateNumberOfMessagesVisible` for the DLQ
#    is the most critical piece of monitoring for this module. It acts as the primary
#    signal that the message processing workflow is failing persistently and requires
#    human intervention.
#
# 2. Conditional Creation: The alarm resource is created conditionally using a `for_each`.
#    It will only be provisioned if a valid SNS Topic ARN is passed via the
#    `cloudwatch_alarms_topic_arn` variable, making monitoring an optional feature.
#
# 3. Integration: This file is designed to be part of the `sqs` module, encapsulating
#    monitoring logic alongside the resources it monitors. It relies on an SNS topic
#    created in the root module to decouple monitoring from notification delivery.
