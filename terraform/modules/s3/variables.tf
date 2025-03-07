# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module.

# --- Default AWS Region --- #
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# --- Replication AWS Region --- #
variable "replication_region" {
  description = "AWS region for replication bucket." # Description: Replication region
  type        = string
}

# --- Environment --- #
variable "environment" {
  description = "Deployment environment (dev, stage, prod)." # Description: Environment
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "Environment must be 'dev', 'stage', or 'prod'." # Validation error message
  }
}

# --- Name Prefix --- #
variable "name_prefix" {
  description = "Prefix for S3 resource names (uniqueness)." # Description: Name prefix
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS Account ID for bucket policies (security)." # Description: AWS Account ID
  type        = string
}

# --- KMS Key ARN --- #
variable "kms_key_arn" {
  description = "ARN of KMS key for S3 bucket encryption (security)." # Description: KMS Key ARN
  type        = string

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "kms_key_arn cannot be empty." # Validation error message
  }
}

# --- KMS Replica Key ARN --- #
variable "kms_replica_key_arn" {
  description = "ARN of KMS replica key in replication region for S3 bucket encryption." # Description: KMS Replica Key ARN
  type        = string
  default     = null # May be null if replication is not used
}

# --- Noncurrent Version Retention Days --- #
variable "noncurrent_version_retention_days" {
  description = "Retention days for noncurrent object versions (versioning)." # Description: Retention days
  type        = number

  validation {
    condition     = var.noncurrent_version_retention_days > 0
    error_message = "Retention days > 0 required." # Validation error message
  }
}

# --- SNS Topic ARN --- #
variable "sns_topic_arn" {
  description = "ARN of SNS Topic for bucket notifications." # Description: SNS Topic ARN
  type        = string
}

# --- Replication Region SNS Topic ARN --- #
variable "replication_region_sns_topic_arn" {
  description = "ARN of SNS Topic in replication region for bucket notifications." # Description: Replication Region SNS Topic ARN
  type        = string
  default     = "" # Может быть пустым, если не используется
}

# --- Default Region Buckets Config --- #
variable "default_region_buckets" {
  type = map(object({
    enabled     = optional(bool, true)
    versioning  = optional(bool, true)
    replication = optional(bool, true)
    logging     = optional(bool, true)
    region      = optional(string, null) # Optional: region (defaults to provider)
  }))
  description = "Config for default AWS region buckets." # Description: Default region buckets config
  default     = {}
}

# --- Replication Region Buckets Config --- #
variable "replication_region_buckets" {
  type = map(object({
    enabled    = optional(bool, true)
    versioning = optional(bool, true) # Required: versioning for replication    
    region     = string               # Required: AWS region for replication
  }))
  description = "Config for replication region buckets." # Description: Replication region buckets config
  default     = {}
}

# --- Enable S3 Script --- #
variable "enable_s3_script" {
  description = "Enable uploading scripts to S3." # Description: Enable S3 Script
  type        = bool
  default     = false
}

# --- S3 Scripts Map --- #
variable "s3_scripts" {
  description = "Map of files for scripts bucket upload." # Description: S3 Scripts Map
  type        = map(string)
  default     = {}
}

# --- Enable CORS --- #
variable "enable_cors" {
  description = "Enable CORS for WordPress media bucket." # Description: Enable CORS
  type        = bool
  default     = false # Default: CORS disabled
}

# --- Allowed Origins --- #
variable "allowed_origins" {
  description = "List of allowed origins for S3 CORS." # Description: Allowed Origins
  type        = list(string)
  default     = ["https://example.com"]
}

# --- Enable DynamoDB --- #
variable "enable_dynamodb" {
  description = "Enable DynamoDB for Terraform state locking." # Description: Enable DynamoDB
  type        = bool
  default     = false

  validation {
    condition     = var.enable_dynamodb ? contains(keys(var.default_region_buckets), "terraform_state") && var.default_region_buckets["terraform_state"].enabled : true
    error_message = "enable_dynamodb requires terraform_state bucket enabled." # Validation error message
  }
}

# --- Enable Lambda --- #
variable "enable_lambda" {
  description = "Enable Lambda for DynamoDB TTL automation." # Description: Enable Lambda
  type        = bool
  default     = false

  validation {
    condition     = var.enable_lambda ? var.enable_dynamodb : true
    error_message = "enable_lambda requires enable_dynamodb." # Validation error message
  }
}

# --- Lambda Log Retention Days --- #
variable "lambda_log_retention_days" {
  description = "Log retention days for Lambda function." # Description: Log retention days
  type        = number
  default     = 30
}

# --- Lambda VPC ID --- #
variable "vpc_id" {
  description = "VPC ID for Lambda security group." # Description: VPC ID
  type        = string
}

# --- Private Subnet IDs --- #
variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda." # Description: Private Subnet IDs
  type        = list(string)
}

# --- Private Subnet CIDR Blocks --- #
variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnet security group ingress." # Description: Private Subnet CIDR Blocks
  type        = list(string)
}

# --- Lambda Endpoint ID --- #
variable "lambda_endpoint_id" {
  description = "ID of Lambda VPC Endpoint." # Description: Lambda Endpoint ID
  type        = string
}

# --- DynamoDB Endpoint ID --- #
variable "dynamodb_endpoint_id" {
  description = "ID of DynamoDB VPC Endpoint." # Description: DynamoDB Endpoint ID
  type        = string
}

# --- CloudWatch Logs Endpoint ID --- #
variable "cloudwatch_logs_endpoint_id" {
  description = "ID of CloudWatch Logs VPC Endpoint." # Description: CloudWatch Logs Endpoint ID
  type        = string
}

# --- SQS Endpoint ID --- #
variable "sqs_endpoint_id" {
  description = "ID of SQS VPC Endpoint." # Description: SQS Endpoint ID
  type        = string
}

# --- KMS Endpoint ID --- #
variable "kms_endpoint_id" {
  description = "ID of KMS VPC Endpoint." # Description: KMS Endpoint ID
  type        = string
}

# --- Module Notes --- #
# General notes for S3 module variables.
#
# 1. Bucket Config: 'buckets' map controls bucket creation and properties.
# 2. Security: KMS encryption, bucket policies, HTTPS enforced.
# 3. Replication: 'replication_region', ensure IAM permissions.
# 4. WordPress: CORS ('enable_cors', 'allowed_origins'), scripts upload ('enable_s3_script', 's3_scripts').
# 5. Logging: Centralized logging for configured buckets.
# 6. Lifecycle: 'noncurrent_version_retention_days' for versioning.
# 7. Notifications: 'sns_topic_arn' for bucket notifications.
# 8. DynamoDB/Lambda (Optional): DynamoDB state locking ('enable_dynamodb'), Lambda TTL automation ('enable_lambda').
# 9. Lambda VPC (Optional): VPC settings for Lambda within VPC.