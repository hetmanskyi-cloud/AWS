# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Configuration ---#
# Region where the replication bucket will be created, typically different from the primary region.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- Environment Variable --- #
# Determines the deployment environment (e.g., dev, stage, prod).
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Name Prefix Variable --- #
# Prefix for resource names, ensuring unique and identifiable resources.
variable "name_prefix" {
  description = "Name prefix for S3 resources to ensure uniqueness."
  type        = string
}

# --- AWS Account ID Variable --- #
# Used for configuring bucket policies and ensuring access is restricted to this AWS account.
variable "aws_account_id" {
  description = "AWS Account ID for configuring S3 bucket policies and ensuring resource security."
  type        = string
}

# --- KMS Key ARN Variable --- #
# Specifies the ARN of the KMS key for encrypting S3 bucket data at rest.
variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting S3 buckets to enhance security."
  type        = string

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "The kms_key_arn variable cannot be empty."
  }
}

# --- Lifecycle Configuration Variable --- #
# Retention period for noncurrent object versions (applies only to buckets with versioning enabled).
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions in S3 buckets for versioning."
  type        = number

  validation {
    condition     = var.noncurrent_version_retention_days > 0
    error_message = "Retention days must be greater than 0."
  }
}

# --- SNS Topic ARN Variable --- #

# Specifies the ARN of the SNS Topic for bucket notifications.
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for bucket notifications."
  type        = string
}

# --- S3 Bucket Configuration Variables --- #
# Defines input variables for configuring S3 buckets in different regions.

variable "default_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, false)
    replication = optional(bool, false)
    logging     = optional(bool, false)
    region      = optional(string, null) # Optional region, defaults to provider region if not set
  }))
  description = "Configuration for S3 buckets in the default AWS region."
  default     = {}
}

variable "replication_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, true)  # Versioning MUST be enabled for replication destinations
    replication = optional(bool, false) # Replication is not applicable for replication buckets themselves
    logging     = optional(bool, false)
    region      = string # AWS region for the replication bucket (REQUIRED)
  }))
  description = "Configuration for S3 buckets specifically in the replication AWS region."
  default     = {}
}

# Flag to enable uploading scripts to S3
variable "enable_s3_script" {
  description = "Flag to enable uploading scripts to S3"
  type        = bool
  default     = false
}

# Map of files to be uploaded to the scripts bucket
variable "s3_scripts" {
  description = "Map of files to be uploaded to the scripts bucket"
  type        = map(string)
  default     = {}
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# Allowed origins
variable "allowed_origins" {
  description = "List of allowed origins for S3 bucket CORS"
  type        = list(string)
  default     = ["https://example.com"]
}

# --- DynamoDB and Lambda Configuration --- #

# Enable DynamoDB table for Terraform state locking.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for Terraform state locking."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_dynamodb ? lookup(var.default_region_buckets, "terraform_state", false) : true
    error_message = "enable_dynamodb requires buckets[\"terraform_state\"] to be true."
  }
}

# Enable Lambda for DynamoDB TTL automation.
variable "enable_lambda" {
  description = "Enable Lambda for DynamoDB TTL automation."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_lambda ? var.enable_dynamodb : true
    error_message = "enable_lambda requires enable_dynamodb = true."
  }
}

# Log retention period for Lambda functions.
variable "lambda_log_retention_days" {
  description = "Number of days to retain logs for the Lambda function."
  type        = number
  default     = 30
}

# --- VPC Variables for Lambda --- #

# VPC ID where the Lambda security group will be created.
variable "vpc_id" {
  description = "VPC ID where Lambda security group will be created."
  type        = string
}

# List of private subnet IDs for the Lambda function.
variable "private_subnet_ids" {
  description = "List of private subnet IDs for the Lambda function."
  type        = list(string)
}

# CIDR blocks of private subnets for security group ingress rules.
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks of private subnets for security group ingress."
  type        = list(string)
}

# --- VPC Endpoints --- #

variable "lambda_endpoint_id" {
  description = "The ID of the Lambda Interface Endpoint"
  type        = string
}

variable "dynamodb_endpoint_id" {
  description = "The ID of the DynamoDB Gateway Endpoint"
  type        = string
}

variable "cloudwatch_logs_endpoint_id" {
  description = "The ID of the CloudWatch Logs Interface Endpoint"
  type        = string
}

variable "sqs_endpoint_id" {
  description = "The ID of the SQS Interface Endpoint"
  type        = string
}

variable "kms_endpoint_id" {
  description = "The ID of the KMS Interface Endpoint"
  type        = string
}

# --- Notes --- #
# 1. Bucket Configuration:
#    - The 'buckets' map controls which S3 buckets are created and their properties (versioning, replication, logging).
# 2. Security:
#    - KMS encryption ('kms_key_arn') is used for data at rest.
#    - Bucket policies enforce access restrictions.
#    - HTTPS is enforced for all buckets.
# 3. Replication:
#    - Cross-region replication is configured using 'replication_region'.
#    - Ensure appropriate IAM permissions are in place for replication.
# 4. WordPress Integration:
#    - CORS can be enabled for the 'wordpress_media' bucket using 'enable_cors' and 'allowed_origins'.
#    - WordPress scripts can be uploaded to the 'scripts' bucket using 'enable_s3_script' and 's3_scripts'.
# 5. Logging:
#    - Centralized logging is enabled for configured buckets.
# 6. Lifecycle Management:
#    - Noncurrent version retention is configured using 'noncurrent_version_retention_days'.
# 7. Notifications:
#    - Bucket notifications are sent to the SNS topic specified by 'sns_topic_arn'.
# 8. DynamoDB and Lambda (Optional):
#    - DynamoDB ('enable_dynamodb') can be used for Terraform state locking.
#    - Lambda ('enable_lambda') can automate DynamoDB TTL cleanup (requires DynamoDB to be enabled).
# 9. Lambda VPC Configuration (Optional):
#    - VPC settings ('vpc_id', 'private_subnet_ids', 'private_subnet_cidr_blocks') are required if Lambda is deployed within a VPC.