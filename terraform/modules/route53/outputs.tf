# --- Route53 Module Outputs --- #
# These outputs expose key attributes of the created Route 53 resources.

output "custom_zone_id" {
  description = "The ID of the created Route 53 Hosted Zone."
  value       = aws_route53_zone.custom_zone.zone_id
}

output "custom_zone_name_servers" {
  description = "A list of Name Server (NS) records for the created Hosted Zone. These values must be configured at your domain registrar."
  value       = aws_route53_zone.custom_zone.name_servers
}

# --- Outputs for ALIAS (A) records pointing to CloudFront --- #
output "site_alias_fqdns" {
  description = <<EOT
A list of FQDNs (fully qualified domain names) for all ALIAS records pointing to the CloudFront distribution.
Each FQDN is the final DNS name (e.g., "example.com." or "www.example.com.") as it appears in Route 53.
Use this output for verification, debugging, or integration with monitoring tools.
EOT
  value       = [for record in aws_route53_record.site_alias : record.fqdn]
}

# --- Notes --- #
# 1. CRITICAL ACTION REQUIRED: `zone_name_servers`
#    - The `custom_zone_name_servers` output provides a list of 4 AWS name servers.
#    - You MUST log in to your domain registrar (e.g., GoDaddy, Namecheap, Google Domains) where you
#      purchased your domain and update the custom NS records to these values.
#    - This step delegates DNS control for your domain to AWS Route 53. Without this,
#      none of the DNS records created by this module will have any effect.
#
# 2. `custom_zone_id` (Output):
#    - This ID can be useful for other integrations, such as granting IAM permissions
#      to specific hosted zones.
#
# 3. 'site_alias_fqdns' helps verify your CloudFront endpoints.
#
# 4. All required values for ACM, CloudFront, and Route53 integration can be passed through 'terraform.tfvars' for 1-click automation.
