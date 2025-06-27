# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# --- SQS Queue Resource --- #
# This file defines the SQS queue used as a Dead Letter Queue (DLQ)
# for other services like AWS Lambda.

# --- Dead Letter Queue (DLQ) --- #
# This resource creates a standard SQS queue with server-side encryption.
# It is intended to receive and store failed invocation events for later analysis.
resource "aws_sqs_queue" "lambda_dlq" {
  # Dynamic queue name for clear identification.
  name = "${var.name_prefix}-${var.queue_name}-${var.environment}"

  # Enables server-side encryption (SSE) using the provided KMS key.
  kms_master_key_id = var.kms_key_arn
  # The number of seconds to wait before attempting to re-process a message from the DLQ.
  kms_data_key_reuse_period_seconds = 300

  # The amount of time in seconds that a message is hidden from subsequent retrieve
  # requests after being retrieved. Should be greater than the consumer's (e.g., Lambda) timeout.
  visibility_timeout_seconds = 300 # 5 minutes

  # The length of time, in seconds, for which Amazon SQS retains a message.
  message_retention_seconds = 1209600 # 14 days, the maximum value.

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.queue_name}-${var.environment}"
  })
}

# --- Notes --- #
# 1. Purpose: This module is designed to create a single, secure SQS queue, primarily for use as a DLQ.
# 2. Encryption: Server-side encryption using a customer-managed KMS key is enforced via the 'kms_master_key_id' argument.
# 3. Message Retention: Messages are stored for the maximum duration of 14 days to ensure ample time for debugging failed events.
# 4. Visibility Timeout: Set to 5 minutes by default, which should be sufficient for most manual or automated inspection processes.
