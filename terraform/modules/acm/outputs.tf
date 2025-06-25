# --- ACM Module Outputs --- #
# These outputs expose key attributes of the created ACM certificate for use in other modules.

output "acm_arn" {
  description = "The Amazon Resource Name (ARN) of the certificate. Use this to attach the certificate to CloudFront or other AWS services."
  value       = aws_acm_certificate.custom.arn
}

output "acm_id" {
  description = "The ID of the certificate (identical to the ARN)."
  value       = aws_acm_certificate.custom.id
}

output "domain_validation_options" {
  description = "A set of objects containing the DNS records required for validating the certificate. Use these values to create the necessary CNAME records in Route53 for DNS validation."
  value       = aws_acm_certificate.custom.domain_validation_options
  sensitive   = true # The record value can be considered sensitive.
}

# --- Notes --- #
# 1. 'acm_arn' is consumed by the CloudFront module to enable SSL/TLS for your custom domain.
# 2. 'domain_validation_options' must be passed to a Route53 module or resource to create DNS records
#    for validation. Without this step, the certificate will remain in 'PENDING_VALIDATION' state.
#    This output is marked as 'sensitive = true' as it contains record values that should not be exposed publicly.
