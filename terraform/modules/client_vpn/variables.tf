# --- Client VPN Module Variables --- #

# --- General Naming and Tagging Variables --- #

variable "name_prefix" {
  description = "A prefix used for all resource names to ensure uniqueness (e.g., 'myproject')."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'stage', 'prod')."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all taggable resources."
  type        = map(string)
}

# --- KMS Key Configuration --- #

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use for encrypting the CloudWatch Log Group."
  type        = string
  default     = null
}

# --- Client VPN Configuration --- #

variable "client_vpn_client_cidr_blocks" {
  description = "List of IPv4 address ranges, in CIDR notation, from which to assign client IP addresses (e.g., ['10.100.0.0/22'])."
  type        = list(string)
  default     = []
}

variable "client_vpn_split_tunnel" {
  description = "Indicates whether split-tunnel is enabled. If true, only traffic destined for the VPC's CIDR and other specified routes goes through the VPN."
  type        = bool
  default     = true
}

variable "custom_dns_servers" {
  description = "A list of up to two DNS server IPs to be used by clients. Use the VPC's DNS server (e.g., '10.0.0.2') to resolve private hostnames."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.custom_dns_servers) <= 2
    error_message = "Provide at most two DNS servers."
  }
}

# --- Autentication Configuration --- #

variable "authentication_type" {
  description = "The authentication method to use. Valid values are 'certificate' or 'federated'."
  type        = string
  default     = "certificate"

  validation {
    condition     = contains(["certificate", "federated"], var.authentication_type)
    error_message = "Allowed values for authentication_type are 'certificate' or 'federated'."
  }
}

variable "saml_provider_arn" {
  description = "The ARN of the IAM SAML identity provider. Required when authentication_type is 'federated'."
  type        = string
  default     = null
}

variable "enable_self_service_portal" {
  description = "Enable the self-service portal for users to download the client configuration. Recommended for 'federated' authentication."
  type        = bool
  default     = false
}

variable "vpn_access_group_id" {
  description = "The ID of the group to which access is granted. Required for 'federated' authentication to restrict access."
  type        = string
  default     = null
}

# --- Logging Configuration --- #

variable "client_vpn_log_retention_days" {
  description = "The number of days to retain Client VPN connection logs in the CloudWatch Log Group."
  type        = number
  default     = 30

  validation {
    # Check if the provided value is one of the allowed AWS values.
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.client_vpn_log_retention_days)

    # The error_message string is for the user running Terraform
    error_message = "expected retention_in_days to be one of [0 1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1096 1827 2192 2557 2922 3288 3653]"
  }
}

# --- VPC Integration --- #

variable "vpc_id" {
  description = "The ID of the VPC where the Client VPN and its Security Group will be created."
  type        = string
}

variable "vpc_subnet_ids" {
  description = "A list of subnet IDs to associate with the Client VPN endpoint for high availability."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "The primary CIDR block of the VPC. Used for authorization rules and routes."
  type        = string
}

# --- Notes --- #
# 1. Naming and Tagging:
#    - The `name_prefix`, `environment`, and `tags` variables ensure that all resources created
#      by this module follow the project's consistent naming and tagging conventions.
#
# 2. Client CIDR Block:
#    - This CIDR block CANNOT overlap with the VPC's CIDR or any connected networks.
#    - Choosing an appropriate, non-conflicting range is essential for the VPN to function correctly.
#
# 3. Split Tunneling:
#    - The default value `true` for `client_vpn_split_tunnel` is a common best practice.
#    - It ensures that only corporate network traffic is routed through the VPN, while general
#      internet traffic from the user's machine goes directly to the internet. This improves performance
#      and reduces unnecessary load on the VPN endpoint.
