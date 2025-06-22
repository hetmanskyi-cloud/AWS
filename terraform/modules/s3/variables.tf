# --- S3 Module Variables --- #
# Defines input variables for configuring the S3 module.

# --- Default AWS Region --- #
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# --- Environment --- #
variable "environment" {
  description = "Deployment environment (dev, stage, prod)."
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "Environment must be 'dev', 'stage', or 'prod'."
  }
}

# Tags for resource identification and management
variable "tags" {
  description = "Component-level tags used for identifying resource ownership"
  type        = map(string)
}

# --- Name Prefix --- #
variable "name_prefix" {
  description = "Prefix for S3 resource names (uniqueness)."
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS Account ID for bucket policies (security)."
  type        = string
}

# --- KMS Key ARN --- #
variable "kms_key_arn" {
  description = "ARN of KMS key for S3 bucket encryption (security)."
  type        = string

  validation {
    condition     = length(var.kms_key_arn) > 0
    error_message = "kms_key_arn cannot be empty."
  }
}

# --- KMS Replica Key ARN --- #
variable "kms_replica_key_arn" {
  description = "ARN of KMS replica key in replication region for S3 bucket encryption (optional, dynamically created if replication is enabled)"
  type        = string
  default     = null # May be null if replication is not used
}

# --- Noncurrent Version Retention Days --- #
variable "noncurrent_version_retention_days" {
  description = "Retention days for noncurrent object versions (versioning)."
  type        = number

  validation {
    condition     = var.noncurrent_version_retention_days > 0
    error_message = "Retention days > 0 required."
  }
}

# --- SNS Topic ARN --- #
variable "sns_topic_arn" {
  description = "ARN of SNS Topic for bucket notifications."
  type        = string
}

# --- Replication Region SNS Topic ARN --- #
variable "replication_region_sns_topic_arn" {
  description = "ARN of SNS Topic in replication region for bucket notifications."
  type        = string
  default     = ""
}

# --- Default Region Buckets Configuration --- #
variable "default_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false)
    replication           = optional(bool, false)
    server_access_logging = optional(bool, false)
    region                = optional(string, null) # Optional: region (defaults to provider)
  }))
  description = <<-EOT
    Config for default AWS region buckets.

    NOTE: The 'scripts' bucket must always be enabled (enabled = true).
    It is required for EC2 bootstrap and WordPress deployment via user_data script.
  EOT
  default     = {}
}

# --- Replication Region Buckets Configuration --- #
variable "replication_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false) # Required: versioning for replication
    server_access_logging = optional(bool, false)
    region                = string # Required: AWS region for replication
  }))
  description = "Config for replication region buckets."
  default     = {}
}

# --- WordPress Media Bucket Configuration --- #
variable "wordpress_media_cloudfront_distribution_arn" {
  description = "ARN of CloudFront distribution for wordpress_media bucket policy."
  type        = string
  default     = ""
}

variable "wordpress_media_cloudfront_enabled" {
  description = "Enable CloudFront policy for wordpress_media bucket."
  type        = bool
  default     = false
}

# --- S3 Scripts Map --- #
variable "s3_scripts" {
  description = <<-EOT
    Map of files for scripts bucket upload.
    Scripts will be uploaded only if the 'scripts' bucket is enabled.
    Local fallback is not used — this is the only method of delivery.
  EOT
  type        = map(string)
  default     = {}
}

# --- Enable CORS --- #
variable "enable_cors" {
  description = "Enable CORS for WordPress media bucket."
  type        = bool
  default     = false
}

# --- Allowed Origins --- #
variable "allowed_origins" {
  description = "List of allowed origins for S3 CORS. IMPORTANT: In production, restrict to trusted origins only."
  type        = list(string)
  default     = ["https://example.com"]
}

# --- Enable DynamoDB --- #
variable "enable_dynamodb" {
  description = "Enable DynamoDB for Terraform state locking."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_dynamodb ? contains(keys(var.default_region_buckets), "terraform_state") && var.default_region_buckets["terraform_state"].enabled : true
    error_message = "enable_dynamodb requires terraform_state bucket enabled."
  }
}

# --- ASG Instance Role ARN --- #
variable "asg_instance_role_arn" {
  description = "The ARN of the ASG instance role, used to grant S3 bucket access."
  type        = string
  default     = null
}

# --- CloudFront Logging Configuration --- #
variable "enable_cloudfront_standard_logging_v2" {
  description = "Enable CloudFront standard logging (v2) to CloudWatch Logs and S3"
  type        = bool
  default     = true
}

# --- Notes --- #
# 1. Bucket Configuration: 'default_region_buckets' and 'replication_region_buckets' maps control bucket creation and properties.
# 2. Security: KMS encryption, bucket policies, HTTPS enforced.
# 3. Replication: 'replication_region', ensure IAM permissions.
# 4. WordPress: CORS ('enable_cors', 'allowed_origins'), scripts upload ('s3_scripts').
# 5. Logging: Centralized logging for configured buckets.
# 6. Lifecycle: 'noncurrent_version_retention_days' for versioning.
# 7. Notifications: 'sns_topic_arn' for bucket notifications.
# 8. DynamoDB (Optional): DynamoDB state locking ('enable_dynamodb').
# 9. Best Practice: Validate 'allowed_origins' and restrict in production to prevent CORS vulnerabilities.
