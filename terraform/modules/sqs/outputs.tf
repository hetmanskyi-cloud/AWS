# --- SQS Module Outputs --- #
# Exposes key attributes of all created SQS queues for use in other modules.

locals {
  # Merge all created queues (both main and DLQs) into a single map.
  # This provides a unified data structure for all outputs, making them easier to reference.
  all_queues = merge(aws_sqs_queue.main, aws_sqs_queue.dlq)
}

# --- SQS Queue ARNs --- #
output "queue_arns" {
  description = "A map of logical queue names to their Amazon Resource Names (ARNs). ARNs are essential for configuring IAM policies and triggers (e.g., S3 notifications, Lambda event sources)."
  value       = { for k, q in local.all_queues : k => q.arn }
}

# --- SQS Queue Names --- #
output "queue_names" {
  description = "A map of logical queue names to their actual, unique SQS queue names. Useful for display, logging, or monitoring."
  value       = { for k, q in local.all_queues : k => q.name }
}

# --- SQS Queue URLs --- #
output "queue_urls" {
  description = "A map of logical queue names to their URLs. The URL is the primary endpoint used by SDKs and the AWS CLI to send, receive, and delete messages."
  value       = { for k, q in local.all_queues : k => q.id } # The 'id' attribute of aws_sqs_queue is its URL.
}

# --- Notes --- #
# 1. Accessing Outputs: Since this module creates multiple queues, all outputs are maps.
#    To access the ARN of a specific queue, use its logical key from your variable map. For example:
#    module.sqs.queue_arns["image-processing"]
#
# 2. Identifier Usage:
#    - Use the ARN ('queue_arns') for permissions and integrations (IAM policies, event source mappings).
#    - Use the URL ('queue_urls') for application logic (sending/receiving messages via an SDK or CLI).
#    - Use the Name ('queue_names') for human-readable identification and tagging.
