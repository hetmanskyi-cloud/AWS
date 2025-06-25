# --- Route53 Module Variables --- #

# --- Global Module Configuration --- #
variable "name_prefix" {
  description = "Resource name prefix (e.g., 'myproject')."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., 'dev', 'stage', 'prod')."
  type        = string
}

variable "tags" {
  description = "A map of tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}

# --- Zone and Domain Configuration --- #
variable "custom_domain_name" {
  description = "The root domain name (zone) for which to create the Hosted Zone (e.g., 'example.com')."
  type        = string
}

variable "subject_alternative_names" {
  description = "A list of subject alternative names (SANs) from the ACM certificate that also need DNS records (e.g., [\"www.example.com\"])."
  type        = list(string)
  default     = []
}

# --- ACM Integration Inputs --- #
# These variables consume outputs from the 'acm' module.
variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate that needs to be validated."
  type        = string
}

variable "acm_certificate_domain_validation_options" {
  description = <<EOT
A complex object containing ACM domain validation options.
This value **must be passed from the 'domain_validation_options' output of the ACM module**.
It contains the DNS record names, types, and values needed for certificate validation.
EOT
  type        = any # This is a complex object, so 'any' is the most flexible type.
}

# --- CloudFront Integration Inputs --- #
# These variables consume outputs from the 'cloudfront' module.
variable "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution (e.g., 'd12345.cloudfront.net')."
  type        = string
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "The hosted zone ID for the CloudFront distribution, required for creating ALIAS records."
  type        = string
}

# --- Notes --- #
# 1. This module acts as a central hub, consuming outputs from both the 'acm' and 'cloudfront' modules
#    to complete the custom domain setup.
# 2. `custom_domain_name` is used to create the main Hosted Zone.
# 3. `acm_*` variables are critical for the certificate validation process.
# 4. `cloudfront_*` variables are critical for pointing the custom domain to the live CDN distribution.
