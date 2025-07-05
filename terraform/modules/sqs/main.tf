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

# --- SQS Queue Resources --- #
# To break the dependency cycle between a main queue and its DLQ, we create them in two steps.

# Step 1: Create all Dead Letter Queues (DLQs) first
# We iterate only over the queues marked with 'is_dlq = true'.
# This block creates all the DLQs so they can be referenced by main queues later.
resource "aws_sqs_queue" "dlq" {
  for_each = { for k, q in var.sqs_queues : k => q if q.is_dlq }

  # Naming and Configuration
  name                      = "${var.name_prefix}-${each.value.name}-${var.environment}"
  message_retention_seconds = each.value.message_retention_seconds

  # Security and Encryption
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value.name}-${var.environment}"
  })
}

# Step 2: Create all Main Queues
# We iterate over the queues that are NOT DLQs.
# This breaks the dependency cycle, as the DLQs they reference already exist from Step 1.
resource "aws_sqs_queue" "main" {
  for_each = { for k, q in var.sqs_queues : k => q if !q.is_dlq }

  # Naming and Core Configuration
  name = "${var.name_prefix}-${each.value.name}-${var.environment}"

  # Timeouts and Retention
  visibility_timeout_seconds        = each.value.visibility_timeout_seconds
  message_retention_seconds         = each.value.message_retention_seconds
  kms_data_key_reuse_period_seconds = each.value.kms_data_key_reuse_period_seconds

  # Security and Encryption
  kms_master_key_id = var.kms_key_arn

  # DLQ and Redrive Policy
  # The Redrive Policy now safely references a queue created in the 'dlq' resource block above.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.value.dlq_key].arn
    maxReceiveCount     = each.value.max_receive_count
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value.name}-${var.environment}"
  })

  # Ensure the DLQ exists before creating the main queue that uses it
  depends_on = [aws_sqs_queue.dlq]
}

# --- Notes --- #
# 1. Two-Step Creation: To prevent a dependency cycle where a main queue needs its DLQ's ARN
#    before the DLQ is created, this module creates queues in two distinct steps. First, all
#    queues marked as DLQs are created. Second, all main queues are created, which can then
#    safely reference the ARNs of the now-existing DLQs.
# 2. Automated Redrive Policy: The Redrive Policy is configured via a standard 'jsonencode'
#    function, which is the syntax expected by the SQS resource. This is applied only to
#    the main queues.
