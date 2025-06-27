# --- SQS Module Variables --- #
# Defines input variables for configuring the SQS module.

# --- Naming and Environment --- #

variable "queue_name" {
  description = "The base name of the SQS queue (e.g., 'image-processor-dlq')."
  type        = string
}

variable "name_prefix" {
  description = "A prefix used for naming all SQS resources to ensure uniqueness and consistency."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, stage, prod). Used for naming and tagging."
  type        = string
}

# --- Security and Encryption --- #

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use for server-side encryption (SSE) of the SQS queue."
  type        = string
}

# --- Tagging --- #

variable "tags" {
  description = "A map of tags to apply to all taggable resources created by the module."
  type        = map(string)
  default     = {}
}

# --- Notes --- #
# 1. Naming: Resource names are constructed using 'name_prefix', 'queue_name', and 'environment'.
# 2. Security: A KMS key ARN is required to ensure all messages are encrypted at rest.
