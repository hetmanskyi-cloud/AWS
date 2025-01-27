# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module, allowing customization and flexibility.

# --- AWS Region Configuration ---#
# Region where the replication bucket will be created, typically different from the primary region.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string

  validation {
    condition     = contains(["us-east-1", "eu-west-1"], var.replication_region)
    error_message = "Replication region must be one of 'us-east-1' or 'eu-west-1'."
  }
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

# --- Bucket Configuration Variables --- #

# Map to enable or disable S3 buckets dynamically.
variable "buckets" {
  description = "Map to enable or disable S3 buckets dynamically."
  type        = map(bool)
  default     = {}
}

# Versioning settings are managed in the `terraform.tfvars` file.
variable "enable_versioning" {
  description = "Map of bucket names to enable or disable versioning."
  type        = map(bool)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.enable_versioning) : contains(keys(var.buckets), key) if lookup(var.enable_versioning, key, false)])
    error_message = "All keys in enable_versioning must exist in buckets."
  }
}

# --- Enable Replication Variable --- #
# Enable cross-region replication for S3 buckets.
variable "enable_s3_replication" {
  description = "Enable cross-region replication for S3 buckets."
  type        = bool
  default     = false
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
    condition     = var.enable_dynamodb ? lookup(var.buckets, "terraform_state", false) : true
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

# --- Notes --- #
# 1. **Dynamic Bucket Management**:
#    - The `buckets` variable determines which S3 buckets are created.
#    - The `enable_versioning` map controls versioning settings.
#
# 2. **Security Considerations**:
#    - KMS encryption is used for data protection.
#    - IAM policies ensure restricted access to S3 buckets.
#
# 3. **DynamoDB and Lambda**:
#    - DynamoDB is enabled for Terraform state locking only when needed.
#    - Lambda automates the cleanup of expired state locks.
#
# 4. **Replication Configuration**:
#    - Buckets can be replicated across regions based on `enable_s3_replication`.
#    - Ensure IAM policies allow replication when enabled.
#
# 5. **CORS Handling**:
#    - If `enable_cors` is set to true, CORS policies are applied to WordPress media buckets.
#
# 6. **Best Practices**:
#    - Set appropriate lifecycle rules for cost efficiency.
#    - Use meaningful prefixes and tags for tracking resources.