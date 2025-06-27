# --- SQS Module Outputs --- #
# Exposes key attributes of the created SQS queue for use in other modules.

# --- DLQ Queue ARN --- #
# The primary identifier for the SQS queue.
output "dlq_queue_arn" {
  description = "The Amazon Resource Name (ARN) of the Dead Letter Queue (DLQ)."
  value       = aws_sqs_queue.lambda_dlq.arn
}

# --- DLQ Queue Name --- #
# The name of the SQS queue.
output "dlq_queue_name" {
  description = "The name of the Dead Letter Queue (DLQ)."
  value       = aws_sqs_queue.lambda_dlq.name
}

# --- Notes --- #
# 1. ARN Usage: The 'dlq_queue_arn' output is the primary means by which other modules (e.g., Lambda)
#    should reference this queue for configuring their error handling.
