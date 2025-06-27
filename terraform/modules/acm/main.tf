# --- Terraform Configuration --- #
# Defines the required AWS provider and its version.
# The 'aws.cloudfront' alias is explicitly configured for resources that must reside in us-east-1,
# which is a requirement for ACM certificates used with global services like CloudFront.
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws,
        aws.cloudfront, # Alias for AWS provider configured to us-east-1
      ]
    }
  }
}

# --- AWS Certificate Manager (ACM) Certificate Request --- #

# This resource requests an Amazon-issued SSL/TLS certificate for use with CloudFront.
# DNS validation is automated and should be handled by the 'route53' module using the outputs of this resource.
resource "aws_acm_certificate" "custom" {
  provider = aws.cloudfront # ACM certificates for CloudFront MUST be created in us-east-1.

  domain_name               = var.custom_domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS" # The only method suitable for full automation with Terraform.

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-acm-cert-for-${var.custom_domain_name}-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true # Prevents downtime by creating a new cert before deleting the old one during replacement.
  }
}

# --- Notes --- #
# 1. Region Requirement (us-east-1):
#    - AWS requires that any ACM certificate used with a global service like CloudFront
#      must be provisioned in the 'us-east-1' (N. Virginia) region.
#    - We enforce this by using `provider = aws.cloudfront`, which is an alias for the
#      AWS provider configured to this specific region in the root module.
#
# 2. DNS Validation:
#    - 'validation_method = "DNS"' enables Terraform to automate the process using Route53.
#      The 'domain_validation_options' output is consumed by the Route53 module to create the needed CNAME records.
#    - Email validation is not used as it requires manual intervention.
#
# 3. Lifecycle Hook:
#    - `create_before_destroy = true` is best practice for avoiding service downtime during ACM certificate rotation.
#
# 4. Architectural Scope & Validation Strategy:
#    - This module is intentionally limited to *requesting* the certificate (`aws_acm_certificate`).
#    - The `aws_acm_certificate_validation` resource, which waits for DNS validation to complete,
#      is **deliberately NOT included here to prevent a circular dependency** (`acm` -> `route53` -> `acm`).
#    - **RECOMMENDED IMPLEMENTATION: The `aws_acm_certificate_validation` resource should be
#      placed inside the `route53` module.** This is the ideal location because the `route53` module
#      already depends on this module for validation data and is responsible for creating the required DNS records.
#      This keeps the dependency graph clean and linear.
#
# 5. Module Integration:
#    - The outputs of this module (`acm_arn` and `domain_validation_options`) are designed to be
#      consumed by the 'cloudfront' and 'route53' modules, respectively.
#    - The 'route53' module will use the validation options to create DNS records and manage the full validation lifecycle.
