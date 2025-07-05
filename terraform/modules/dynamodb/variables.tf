# --- DynamoDB Module Variables --- #
# Defines input variables for creating and configuring a generic DynamoDB table.

# --- Naming and Environment --- #

variable "name_prefix" {
  description = "A prefix used for naming the DynamoDB table."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, stage, prod)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the DynamoDB table."
  type        = map(string)
  default     = {}
}

# --- Table Configuration --- #

variable "dynamodb_table_name" {
  description = "The base name for the DynamoDB table (e.g., 'image-metadata')."
  type        = string
}

variable "dynamodb_billing_mode" {
  description = "Controls the billing and capacity mode. Can be PROVISIONED or PAY_PER_REQUEST."
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "Allowed values for billing_mode are PROVISIONED or PAY_PER_REQUEST."
  }
}

variable "dynamodb_table_class" {
  description = "The storage class of the table. Can be STANDARD or STANDARD_INFREQUENT_ACCESS."
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.dynamodb_table_class)
    error_message = "Allowed values for table_class are STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}

# --- Schema and Indexing --- #

variable "dynamodb_hash_key_name" {
  description = "The name of the partition key (hash key) for the table."
  type        = string
}

variable "dynamodb_hash_key_type" {
  description = "The attribute type for the partition key. Valid values are S (String), N (Number), or B (Binary)."
  type        = string
  validation {
    condition     = contains(["S", "N", "B"], var.dynamodb_hash_key_type)
    error_message = "Allowed values for key type are S, N, or B."
  }
}

variable "dynamodb_range_key_name" {
  description = "Optional: The name of the sort key (range key) for the table."
  type        = string
  default     = null
}

variable "dynamodb_range_key_type" {
  description = "The attribute type for the sort key. Required if a range_key_name is set."
  type        = string
  default     = null
  validation {
    condition     = var.dynamodb_range_key_name == null || (var.dynamodb_range_key_name != null && contains(["S", "N", "B"], var.dynamodb_range_key_type))
    error_message = "If range_key_name is specified, range_key_type must be one of: S, N, or B."
  }
}

variable "dynamodb_gsi" {
  description = <<-EOT
  A list of global secondary indexes to create on the table.
  Each object in the list defines one GSI and must contain:
  - name: The name of the GSI.
  - hash_key: The name of the GSI's partition key.
  - hash_key_type: The type of the GSI's partition key (S, N, or B).
  - projection_type: Can be "ALL", "KEYS_ONLY", or "INCLUDE".
  Optional attributes:
  - range_key: The name of the GSI's sort key.
  - range_key_type: The type of the GSI's sort key.
  - non_key_attributes: A list of attributes to project if projection_type is "INCLUDE".

  Note: This variable uses a flexible list of objects with optional attributes.
  This modern approach allows you to declaratively define any number of complex GSIs
  directly in your configuration files without ever needing to modify the module's internal code.
  EOT
  type = list(object({
    name               = string
    hash_key           = string
    hash_key_type      = string
    range_key          = optional(string)
    range_key_type     = optional(string)
    projection_type    = string
    non_key_attributes = optional(list(string))
  }))
  default = []
}

# --- Features and Security --- #

variable "enable_dynamodb_point_in_time_recovery" {
  description = "If true, enables Point-in-Time Recovery (PITR) for the table."
  type        = bool
  default     = true
}

variable "dynamodb_deletion_protection_enabled" {
  description = "If true, enables the native deletion protection for the table. Recommended for production."
  type        = bool
  default     = true
}

variable "enable_dynamodb_ttl" {
  description = "If true, enables Time-to-Live (TTL) for the table to automatically delete expired items."
  type        = bool
  default     = false
}

variable "dynamodb_ttl_attribute_name" {
  description = "The name of the attribute to use for TTL. Required if TTL is enabled."
  type        = string
  default     = "ExpirationTime"
}

variable "kms_key_arn" {
  description = "Optional: The ARN of the KMS key to use for server-side encryption. If not provided, an AWS-owned key is used."
  type        = string
  default     = null
}

# --- Notes --- #
# 1. Reusability: This module is designed to be generic, supporting simple or composite primary keys,
#    optional TTL, and dynamic creation of Global Secondary Indexes.
# 2. Secure Defaults: The module defaults to best practices like PAY_PER_REQUEST billing,
#    Point-in-Time Recovery, and Deletion Protection being enabled.
# 3. Attributes: Only key attributes (for the table and its GSIs) need to be defined. Other attributes
#    can be written at runtime due to DynamoDB's schemaless nature.
