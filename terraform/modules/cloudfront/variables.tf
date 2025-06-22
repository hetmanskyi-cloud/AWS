# --- CloudFront Module Variables --- #

# --- Global Module Configuration --- #
# These variables define general settings that apply across the entire CloudFront module.

variable "name_prefix" {
  description = "A prefix to apply to all resource names for unique identification. E.g., 'myproject'."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'stage', 'prod'). Used in naming and tagging."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to all taggable resources within this module."
  type        = map(string)
  default     = {} # Provide default tags if none are specified, e.g., { Project = "MyProject" }
}

# --- CloudFront Distribution Settings --- #
# Variables specific to the CloudFront distribution itself.

# --- S3 Buckets Configuration --- #
# This variable receives a map of S3 bucket configurations from the root module.
# It allows this module to make conditional decisions based on whether specific
# buckets (like 'wordpress_media' or 'logging') are enabled.
variable "default_region_buckets" {
  description = "A map describing S3 buckets, used for conditional resource creation."

  type = map(object({
    enabled = bool
  }))

  default = {}
}

variable "wordpress_media_cloudfront_enabled" {
  description = "Set to true to enable the CloudFront distribution for WordPress media files."
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution. 'PriceClass_100', 'PriceClass_200', or 'PriceClass_All'."
  type        = string
  default     = "PriceClass_100" # Choose based on your cost/performance requirements
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Invalid CloudFront price class. Must be 'PriceClass_100', 'PriceClass_200', or 'PriceClass_All'."
  }
}

variable "s3_module_outputs" {
  description = "Outputs from the S3 module, containing necessary bucket information for CloudFront origins."
  type = object({
    wordpress_media_bucket_regional_domain_name = string
    # Add any other S3 bucket outputs referenced, e.g., bucket_arn if not passed directly
  })
  # Provide a placeholder structure; actual values will come from module output
  # Example: default = { wordpress_media_bucket_regional_domain_name = "example-bucket.s3.amazonaws.com" }
}

# --- WAF Integration Settings --- #
# Variables controlling the integration with AWS WAF.

variable "enable_cloudfront_waf" {
  description = "Set to true to enable AWS WAFv2 Web ACL protection for the CloudFront distribution."
  type        = bool
  default     = false
}

# --- Logging Configuration (Shared) --- #
# Variables common to both WAF and CloudFront access logging destinations.

variable "logging_bucket_arn" {
  description = "The ARN of the centralized S3 bucket where CloudFront Access Logs and WAF Logs will be stored. This bucket must have a policy granting necessary permissions to AWS logging services."
  type        = string
  # No default, as this is a critical dependency. Example: "arn:aws:s3:::your-central-logs-bucket"
}

# Name of the S3 bucket where CloudFront Standard Logging v2 logs are delivered.
variable "logging_bucket_name" {
  description = "Name of the S3 bucket for CloudFront Standard Logging v2 access logs (must match the bucket used in logging_bucket_arn)."
  type        = string
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key used for encrypting logs in the S3 logging bucket. Set to `null` to disable KMS encryption."
  type        = string
  default     = null # Optional: Set to `null` if you don't use KMS encryption for logs.
}

# --- Kinesis Firehose for WAF Logging Settings --- #
# Variables specific to the Kinesis Firehose setup for WAF logs.

variable "enable_cloudfront_firehose" {
  description = "Set to true to enable Kinesis Firehose for AWS WAF logging. This is required if `enable_cloudfront_waf` is true."
  type        = bool
  default     = false # Usually enabled alongside WAF
}

# --- CloudFront Access Logging v2 Settings (CloudWatch Log Delivery) --- #
# Variables specific to the CloudFront Access Logging v2 setup via CloudWatch Log Delivery.

variable "enable_cloudfront_standard_logging_v2" {
  description = "Enable CloudFront standard logging (v2) to CloudWatch Logs and S3"
  type        = bool
  default     = true
}

# --- SNS Topic for CloudWatch Alarms --- #
# This variable allows the module to send CloudWatch alarms to a specified SNS topic.
variable "sns_alarm_topic_arn" {
  description = "The ARN of the SNS topic to which CloudWatch alarms from this module will be sent."
  type        = string
  default     = null # Making it optional
}

# --- Custom Header for CloudFront to ALB Communication --- #

variable "cloudfront_to_alb_secret_header_value" {
  description = "Secret value for the custom CloudFront → ALB header."
  type        = string
  sensitive   = true
}

# --- ALB DNS Name --- #

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer to use as CloudFront origin"
  type        = string
}
