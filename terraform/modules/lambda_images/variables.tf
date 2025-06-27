# --- General Module Settings --- #
# These variables define the basic context for all resources created by this module.

variable "name_prefix" {
  description = "A prefix used for naming all created resources to ensure uniqueness and consistency."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, stage, prod). Used for naming and tagging."
  type        = string
  validation {
    condition     = can(regex("^(dev|stage|prod)$", var.environment))
    error_message = "The environment variable must be one of: dev, stage, prod."
  }
}

variable "tags" {
  description = "A map of tags to apply to all taggable resources created by the module."
  type        = map(string)
  default     = {}
}

# --- Lambda Function Configuration --- #
# These variables control the core behavior and configuration of the AWS Lambda function itself.

variable "lambda_function_name" {
  description = "The name of the Lambda function."
  type        = string
}

variable "lambda_handler" {
  description = "The function entrypoint in your code. E.g., 'image_processor.handler'."
  type        = string
  default     = "image_processor.lambda_handler" # Default for Python
}

variable "lambda_runtime" {
  description = "The runtime environment for the Lambda function. E.g., 'python3.12'."
  type        = string
  default     = "python3.12"
}

variable "lambda_memory_size" {
  description = "The amount of memory in MB to allocate to the function."
  type        = number
  default     = 256 # Image processing can be memory-intensive
}

variable "lambda_timeout" {
  description = "The maximum amount of time in seconds that the function can run."
  type        = number
  default     = 60 # Default to 1 minute
}

variable "lambda_architecture" {
  description = "The instruction set architecture for the function. Valid values are ['x86_64', 'arm64']."
  type        = list(string)
  default     = ["x86_64"]
}

variable "environment_variables" {
  description = "A map of environment variables to pass to the function's runtime environment."
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "A list of Lambda Layer Version ARNs to attach to the function."
  type        = list(string)
  default     = []
}

variable "ephemeral_storage_mb" {
  description = "The amount of ephemeral storage (/tmp) in MB to allocate for the function. Min 512, Max 10240."
  type        = number
  default     = 512
}

variable "dead_letter_queue_arn" {
  description = "The ARN of an SQS queue to use as a Dead Letter Queue (DLQ). This variable is required as DLQ is a mandatory feature for this module."
  type        = string
  # No default value makes this variable required.
}

# --- Lambda Deployment Package Settings --- #
# Variables related to the source code of the Lambda function.

variable "lambda_source_code_path" {
  description = "The local path to the directory containing the Lambda function's source code."
  type        = string
  default     = "./src"
}

# --- IAM Role and Permissions Settings --- #
# Controls the creation and configuration of the IAM role for the Lambda function.

variable "lambda_iam_policy_attachments" {
  description = "A list of ARNs of existing IAM policies to attach to the Lambda's role."
  type        = list(string)
  default     = []
}

# --- S3 Trigger Configuration --- #
# Variables to configure the S3 bucket event that triggers this Lambda function.

variable "s3_trigger_enabled" {
  description = "If true, creates an S3 trigger for the Lambda function."
  type        = bool
  default     = true
}

variable "triggering_bucket_id" {
  description = "The ID (name) of the S3 bucket that will trigger the Lambda function."
  type        = string
}

variable "s3_events" {
  description = "A list of S3 event types that will trigger the function. E.g., ['s3:ObjectCreated:*']."
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "filter_prefix" {
  description = "An optional prefix for the S3 object key to filter trigger events. E.g., 'uploads/'."
  type        = string
  default     = null
}

variable "filter_suffix" {
  description = "An optional suffix for the S3 object key to filter trigger events. E.g., '.jpg'."
  type        = string
  default     = null
}

variable "lambda_destination_prefix" {
  description = "The destination prefix (folder) within the S3 bucket for processed images."
  type        = string
  default     = "processed/"
}

# --- CloudWatch Alarms Configuration --- #
# Variables for setting up monitoring and alerts for the Lambda function.

variable "alarms_enabled" {
  description = "If true, CloudWatch alarms will be created for the function."
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arn" {
  description = "The ARN of the SNS topic to which alarm notifications will be sent."
  type        = string
  default     = null
}

variable "error_alarm_threshold" {
  description = "The threshold for the number of errors to trigger the error alarm."
  type        = number
  default     = 5
}

variable "throttles_alarm_threshold" {
  description = "The threshold for the number of throttled invocations to trigger the throttles alarm."
  type        = number
  default     = 5
}

variable "duration_alarm_threshold_ms" {
  description = "The threshold in milliseconds for the p95 duration to trigger the duration alarm."
  type        = number
  default     = 30000 # 30 seconds
}

variable "alarm_evaluation_periods" {
  description = "The number of periods over which to evaluate the alarm."
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "The period in seconds over which to evaluate the alarm."
  type        = number
  default     = 300 # 5 minutes
}

# --- Notes --- #
# 1. IAM: The module creates a dedicated IAM role. See `iam.tf` for details.
# 2. Error Handling: A Dead Letter Queue (DLQ) is a mandatory feature for this module to ensure failed events are not lost.
#    The `dead_letter_queue_arn` variable must be provided.
# 3. Features: Supports Lambda Layers, increased Ephemeral Storage, and S3 triggers with fine-grained filtering.
# 4. Monitoring: Includes essential alarms for errors, throttles, and duration, which can be toggled with `alarms_enabled`.
