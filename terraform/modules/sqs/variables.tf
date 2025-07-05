# --- SQS Module Variables --- #
# Defines input variables for creating and configuring one or more SQS queues.

# --- Naming and Environment --- #

variable "name_prefix" {
  description = "A prefix used for all SQS resources to ensure name uniqueness and project consistency."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, stage, prod), used for naming and tagging."
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "The environment must be one of: dev, stage, or prod."
  }
}

# --- Tagging --- #

variable "tags" {
  description = "A map of tags to apply to all taggable resources created by the module."
  type        = map(string)
  default     = {}
}

# --- Security and Encryption --- #

variable "kms_key_arn" {
  description = "The ARN of the customer-managed KMS key used for Server-Side Encryption (SSE) of all SQS queues."
  type        = string
}

# --- Queue Definitions --- #

variable "sqs_queues" {
  description = <<-EOT
  A map of SQS queues to create. The key of the map is a logical name (e.g., "image-processing")
  used for references between resources and in outputs.

  Each object in the map defines a single queue and its properties:
  - name: (String) The base name of the queue.
  - is_dlq: (Bool) Set to 'true' if this queue's primary purpose is to be a Dead Letter Queue.
  - dlq_key: (Optional String) The key of another queue within this map to use as the DLQ.
    If specified, a Redrive Policy will be automatically configured.
  - max_receive_count: (Optional Number) The number of times a message can be un-delivered before
    being sent to the DLQ. Default is 10.
  - visibility_timeout_seconds: (Optional Number) The duration (in seconds) that a message is hidden
    from subsequent retrieve requests after being retrieved by a consumer. Should be at least 6x
    the consumer's (e.g., Lambda) timeout. Default is 30.
  - message_retention_seconds: (Optional Number) The duration (in seconds) for which SQS retains a message.
    Min: 60 (1 minute), Max: 1209600 (14 days). Default is 345600 (4 days).
  - kms_data_key_reuse_period_seconds: (Optional Number) The duration for which SQS can reuse a data key to
    encrypt/decrypt messages before calling KMS again. Reduces KMS costs. Default is 300 (5 minutes).
  EOT
  type = map(object({
    name                              = string
    is_dlq                            = bool
    dlq_key                           = optional(string)
    max_receive_count                 = optional(number, 10)
    visibility_timeout_seconds        = optional(number, 30)
    message_retention_seconds         = optional(number, 345600)
    kms_data_key_reuse_period_seconds = optional(number, 300)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, q in var.sqs_queues :
      q.dlq_key == null || contains(keys(var.sqs_queues), q.dlq_key)
    ])
    error_message = "If 'dlq_key' is specified for a queue, its value must correspond to another key in the 'sqs_queues' map."
  }
  validation {
    condition = alltrue([
      for k, v in var.sqs_queues : !v.is_dlq || v.dlq_key == null
    ])
    error_message = "A queue marked as a DLQ (is_dlq = true) cannot have its own 'dlq_key'."
  }
}

# --- Notes --- #
# 1. Flexible Creation: The 'sqs_queues' map allows for the declarative creation of any number
#    of SQS queues and their Dead Letter Queue (DLQ) pairings from a single variable.
# 2. Automated DLQ Linking: The module automatically configures the Redrive Policy on a main
#    queue if its 'dlq_key' attribute points to a valid DLQ defined in the same map.
# 3. Enforced Security: A 'kms_key_arn' is required, ensuring that all queues created by this
#    module have Server-Side Encryption (SSE) enabled with a customer-managed key by default.
# 4. Best Practices: Remember to set 'visibility_timeout_seconds' to be significantly longer than
#    the timeout of your message consumer (e.g., Lambda function) to prevent duplicate processing.
