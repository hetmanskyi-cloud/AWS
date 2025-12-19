# --- Module: Route 53 DNS Configuration for Custom Domain with ACM and CloudFront --- #
# This Terraform module sets up AWS Route 53 DNS records to enable a custom domain
# to work with an ACM SSL certificate and a CloudFront distribution. It handles the
# creation of the hosted zone, DNS validation records for ACM, and final ALIAS records
# pointing to CloudFront, ensuring the correct order of operations to avoid dependency cycles.

# --- Locals --- #
locals {
  # Combine the root domain and all SANs into a single list for creating ALIAS records.
  all_domains_for_alias = toset(concat([var.custom_domain_name], var.subject_alternative_names))
}

# --- Step 1: Create the Public Hosted Zone --- #
# This resource creates the DNS zone for your custom domain in Route 53.
# checkov:skip=CKV2_AWS_39: "DNS query logging is an optional feature, not a baseline security requirement."
# checkov:skip=CKV2_AWS_38: "DNSSEC is an optional, advanced security feature not required for this project's baseline."
resource "aws_route53_zone" "custom_zone" {
  name = var.custom_domain_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-custom-zone-for-${var.custom_domain_name}-${var.environment}"
  })
}

# --- Step 2: Create DNS Records for ACM Validation --- #
# This resource iterates through the validation options provided by the ACM module
# and creates the necessary CNAME records to prove domain ownership to AWS.
resource "aws_route53_record" "custom_cert_validation" {
  for_each = {
    for dvo in var.acm_certificate_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true # Recommended for validation records that may change.
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.custom_zone.zone_id
}

# --- Step 3: Wait for ACM Certificate Validation --- #
# This resource pauses Terraform's execution until AWS confirms that the DNS validation
# records (created above) are in place and the certificate has been successfully issued.
# This prevents the final ALIAS records from being created prematurely.
resource "aws_acm_certificate_validation" "custom_acm_validation" {
  certificate_arn         = var.acm_certificate_arn
  validation_record_fqdns = [for record in aws_route53_record.custom_cert_validation : record.fqdn]
}

# --- Step 4: Create ALIAS Records Pointing to CloudFront --- #
# This resource creates the final A-records (as ALIAS) that point your custom domain
# and its subdomains directly to the CloudFront distribution.
# It depends on the successful completion of the ACM certificate validation.
resource "aws_route53_record" "site_alias" {
  for_each = local.all_domains_for_alias

  zone_id = aws_route53_zone.custom_zone.zone_id
  name    = each.value # e.g., 'example.com' or 'www.example.com'
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false # Standard for CloudFront aliases.
  }

  depends_on = [aws_acm_certificate_validation.custom_acm_validation] # Explicit dependency.
}

# --- Notes --- #
# 1. Execution Order: This module follows a strict, four-step logical sequence.
#    a. A Route 53 zone is created for the domain.
#    b. DNS records for ACM validation are created within that zone.
#    c. The `aws_acm_certificate_validation` resource waits until the certificate is issued.
#    d. Only after successful validation are the final ALIAS records created to point to CloudFront.
#
# 2. ACM Validation Resource:
#    - As per our architectural decision, the `aws_acm_certificate_validation` resource resides here.
#    - This cleanly resolves the dependency chain without creating a cycle, as this module naturally
#      sits between 'acm' and the final desired state.
#
# 3. ALIAS Records vs. CNAME:
#    - We use ALIAS records ('type = "A"' with an 'alias' block) to point to CloudFront.
#    - This is the AWS-recommended best practice. It works for the root domain (apex) and is more
#      efficient than a CNAME record.
#
# 4. Dependency Management:
#    - An explicit `depends_on` is added to the final ALIAS records. While Terraform might infer this
#      dependency, making it explicit ensures the sequence is always respected and improves code clarity.
#
# 5. Usage and Integration Guide:
#    a. Connection Flow:
#       - Pass the 'domain_validation_options' and 'acm_arn' outputs from the ACM module as inputs to this module.
#       - Pass the 'cloudfront_distribution_domain_name' and 'cloudfront_distribution_hosted_zone_id' outputs
#         from the CloudFront module as inputs here.
#
#    b. CRITICAL ACTION after `terraform apply`:
#       - The `custom_zone_name_servers` output contains a list of 4 AWS name servers.
#       - You MUST log into your domain registrar (e.g., GoDaddy, Namecheap) and update the
#         NS records for your domain to these values. This delegates DNS control to AWS.
#       - DNS propagation can take from a few minutes to 24 hours.
#
#    c. Full Automation:
#       - With correct values passed from other modules, the entire flow (certificate request,
#         DNS validation, and CloudFront aliasing) is fully automated by Terraform.
