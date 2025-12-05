# --- General Module Settings --- #
# These variables define the basic context for all resources created by this module.

variable "aws_region" {
  description = "The AWS region where resources are deployed."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID."
  type        = string
}

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

variable "lambda_environment_variables" {
  description = "A map of environment variables to pass to the function's runtime environment."
  type        = map(string)
  default = {
    TARGET_WIDTH = "1024"
  }
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

  validation {
    condition     = can(regex("^arn:aws:sqs:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9-_]+$", var.dead_letter_queue_arn))
    error_message = "The Dead Letter Queue ARN must be a valid SQS ARN."
  }
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

# --- SQS Trigger Configuration --- #

variable "sqs_trigger_queue_arn" {
  description = "The ARN of the SQS queue that triggers the Lambda function."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:sqs:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9-_]+$", var.sqs_trigger_queue_arn))
    error_message = "The SQS Trigger Queue ARN must be a valid SQS ARN."
  }
}

variable "sqs_batch_size" {
  description = "The maximum number of records to retrieve from the SQS queue in each batch."
  type        = number
  default     = 5
}

# --- DynamoDB Integration Variables --- #

variable "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table, used for IAM policy permissions."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:dynamodb:[a-z0-9-]+:[0-9]{12}:table/[a-zA-Z0-9-_]+$", var.dynamodb_table_arn))
    error_message = "The DynamoDB Table ARN must be a valid DynamoDB Table ARN."
  }
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table. Used to construct environment variables inside the module."
  type        = string
}

# --- S3 Permissions Configuration --- #

variable "source_s3_bucket_name" {
  description = "The name of the S3 bucket where source images are stored. Required for IAM permissions."
  type        = string
}

variable "source_s3_prefix" {
  description = "The prefix (folder) within the source S3 bucket where original images are."
  type        = string
  default     = "uploads/"
}

variable "destination_s3_prefix" {
  description = "The prefix (folder) where processed images will be stored."
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

variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
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

# --- KMS Key ARN --- #
variable "kms_key_arn" {
  description = "ARN of KMS key for S3 bucket encryption (security)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-zA-Z0-9-]+$", var.kms_key_arn))
    error_message = "The KMS Key ARN must be a valid KMS Key ARN."
  }
}

# --- Tracing Configuration --- #
variable "enable_lambda_tracing" {
  description = "If true, enables AWS X-Ray active tracing for the Lambda function."
  type        = bool
  default     = true
}

# --- Notes --- #
# 1. Architecture: This module creates an SQS-triggered Lambda function. It's designed to be part of a larger
#    S3 -> SQS -> Lambda -> DynamoDB event-driven pipeline.
# 2. IAM: A dedicated IAM role is created in `iam.tf`. It requires permissions to read from the SQS trigger queue,
#    write to the SQS DLQ, get/put objects in S3, and write items to DynamoDB.
# 3. Dependencies: This module is not standalone. It requires ARNs and names for several external resources:
#    - The main SQS queue that acts as the trigger.
#    - The SQS Dead Letter Queue (DLQ) for error handling.
#    - The DynamoDB table for storing metadata.
#    - The S3 bucket for reading/writing images.
# 4. Features: Supports Lambda Layers for dependencies and increased Ephemeral Storage for processing large files.
