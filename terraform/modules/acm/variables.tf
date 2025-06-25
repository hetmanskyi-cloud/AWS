# --- AWS Certificate Manager (ACM) Module Variables --- #

# General module variables
variable "name_prefix" {
  description = "Resource name prefix (e.g., 'myproject')."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., 'dev', 'stage', 'prod')."
  type        = string
}

variable "tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}

# Certificate configuration
variable "custom_domain_name" {
  description = "Main domain (FQDN) for which the certificate should be issued (e.g., 'example.com')."
  type        = string
}

variable "subject_alternative_names" {
  description = "List of additional domains (SANs) included in the certificate (e.g., [\"www.example.com\"])."
  type        = list(string)
  default     = []
}

# --- Notes --- #
# 1. Variables 'name_prefix', 'environment', and 'tags' ensure consistent naming and tagging.
# 2. 'custom_domain_name' is required for the ACM certificate.
# 3. 'subject_alternative_names' is optional, but important for covering both root and subdomains (e.g., 'example.com' and 'www.example.com').
# 4. Best practice: Pass all variables from your project's main 'terraform.tfvars' for full automation and environment portability.
