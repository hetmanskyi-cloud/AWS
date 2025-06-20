# --- Terraform Configuration --- #
# Defines the required AWS provider and its version.
# The 'aws.cloudfront' alias is explicitly configured for resources that must reside in us-east-1,
# such as CloudFront distributions, WAF Web ACLs, and related IAM/Firehose/CloudWatch Log Delivery components.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws,            # Default AWS provider alias
        aws.cloudfront, # Alias for AWS provider configured to us-east-1
      ]
    }
  }
}

# --- AWS Account Identity Data Source --- #
# This data source retrieves the AWS account ID for use in resource ARNs,
# S3 path constructions, and tagging. It is required for dynamically referencing
# the current AWS account in output variables and policy documents.
data "aws_caller_identity" "current" {}

# --- CloudFront Distribution for WordPress Media CDN --- #
# This module creates a secure and performant CloudFront CDN to serve static media files
# (images, videos, documents) from a private S3 bucket for WordPress.
# All CloudFront-specific resources are deployed using the 'aws.cloudfront' provider (us-east-1),
# as mandated by AWS for global CloudFront and WAF services.

# --- Locals --- #
# Centralized conditional logic for enabling CloudFront resources.
# This variable controls whether CloudFront media distribution should be enabled 
# based on the configuration in 'default_region_buckets' and 'wordpress_media_cloudfront_enabled'.
# When both conditions are true, CloudFront media distribution will be created.
locals {
  enable_cloudfront_media_distribution = var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_cloudfront_enabled
}

# --- Origin Access Control (OAC) for S3 --- #
# CloudFront Origin Access Control (OAC) for S3.
# This OAC ensures that only CloudFront has access to fetch objects from the private WordPress media S3 bucket.
# The signing behavior and protocol are configured to 'always' and 'sigv4' respectively, ensuring secure and authenticated requests.
resource "aws_cloudfront_origin_access_control" "wordpress_media_oac" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  name                              = "${var.name_prefix}-wordpress-media-oac-${var.environment}"
  description                       = "OAC for CloudFront to securely access the WordPress media S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Cache Policy for WordPress Media --- #
# Defines optimal caching behavior for static media, enhancing performance and reducing origin load.
# It disables cookies and query strings, while enabling Brotli and GZIP compression.
resource "aws_cloudfront_cache_policy" "wordpress_media_cache_policy" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  name        = "${var.name_prefix}-wordpress-media-cache-policy-${var.environment}"
  comment     = "Optimized cache policy for WordPress media static files"
  default_ttl = 86400 # 24 hours (default for development/staging; adjust for production)
  max_ttl     = 86400
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Origin"] # Essential for CORS (Cross-Origin Resource Sharing) support
      }
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# --- CloudFront Distribution --- #
# Creates the CloudFront distribution for serving static media files from the private S3 origin.
# The distribution uses the custom cache policy defined earlier to ensure optimal performance.
# Logging is handled separately through CloudWatch Log Delivery in `cloudfront/logging.tf`, ensuring efficient and cost-effective log storage.

# CloudFront Standard Logging v2 (CloudWatch Log Delivery to S3 in Parquet format) is enabled instead of the legacy logging_config block.
# See the output 'cloudfront_standard_logging_v2_log_prefix' for the S3 path to logs.
# tfsec:ignore:aws-cloudfront-enable-logging
resource "aws_cloudfront_distribution" "wordpress_media" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for WordPress media (dev/stage environment)"
  price_class     = var.cloudfront_price_class # Configurable price class (e.g., PriceClass_100 for lower cost, PriceClass_All for global coverage)

  # --- S3 Origin (Private) --- #
  # Defines the private S3 bucket as the content source, accessible only via OAC.
  origin {
    domain_name              = var.s3_module_outputs.wordpress_media_bucket_regional_domain_name
    origin_id                = "wordpress-media-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.wordpress_media_oac[0].id
  }

  # --- Default Cache Behavior --- #
  # Specifies how CloudFront handles requests by default, linking to the optimized cache policy.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "wordpress-media-origin"
    viewer_protocol_policy = "redirect-to-https" # All HTTP requests are redirected to HTTPS for security
    compress               = true

    cache_policy_id = aws_cloudfront_cache_policy.wordpress_media_cache_policy[0].id

    # Utilizes an AWS-managed response headers policy to automatically add essential security headers and handle CORS.
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"

    # CloudFront Function for advanced/custom security headers (optional, mutually exclusive with response_headers_policy_id).
    # Uncomment the block below and comment out the line above if you need custom headers (e.g., CSP).
    # function_association {
    #   event_type   = "viewer-response"
    #   function_arn = aws_cloudfront_function.security_headers_function[0].arn
    # }
  }

  # --- Viewer Certificate (Default CloudFront SSL) --- #
  # Configures SSL using the default CloudFront certificate for simplicity in non-production environments.
  # For production, a custom domain and an ACM certificate (in us-east-1) are recommended.
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # --- Lifecycle Configuration --- #
  # This lifecycle block ensures that changes to the minimum_protocol_version are ignored
  # when the default CloudFront domain is used (since CloudFront automatically sets TLSv1).
  # If using a custom domain with an ACM certificate, you can set minimum_protocol_version to TLSv1.2 or TLSv1.3,
  # but with the default domain, it will remain TLSv1.
  lifecycle {
    ignore_changes = [
      viewer_certificate[0].minimum_protocol_version
    ]
  }

  # --- Geo Restrictions --- #
  # Controls content delivery based on geographical location. Set to 'none' for global access.
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  # --- WAF Web ACL Association (Optional) --- #
  # Integrates CloudFront with AWS WAF for Layer 7 security, if WAF is enabled for the distribution.
  web_acl_id = var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null

  # --- Resource Tags --- #
  # Applies consistent tagging across the CloudFront distribution for identification and cost management.
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-wordpress-media-cdn-${var.environment}"
  })
}

# --- CloudFront Module Notes --- #
# 1. All CloudFront-related resources (distributions, OACs, cache policies, and associated WAF/Firehose/CloudWatch Log Delivery
#    components) must be provisioned in the us-east-1 region using the 'aws.cloudfront' provider alias.
#    This is a global AWS service requirement, irrespective of your primary AWS region.
# 2. This module configures a CDN for static WordPress media, ensuring secure delivery from a private S3 bucket.
#    Access to the S3 origin is strictly controlled via Origin Access Control (OAC); direct public S3 bucket access is forbidden.
#    The S3 bucket policy (managed externally in the S3 module) must grant necessary permissions to the CloudFront OAC principal.
# 3. For development and staging environments, the default AWS-managed SSL certificate and CloudFront domain are utilized.
#    For production deployments, it is strongly advised to provision a custom domain name and an AWS Certificate Manager (ACM)
#    certificate in us-east-1, integrated with Route53 alias records for a custom endpoint.
# 4. The applied cache policy is finely tuned for static content, excluding cookies and query strings from the cache key,
#    and enabling Brotli/GZIP compression to optimize delivery speed and minimize bandwidth consumption.
# 5. Only safe HTTP methods (GET, HEAD, OPTIONS) are permitted for content requests, and all HTTP traffic is automatically
#    redirected to HTTPS, enforcing secure communication channels.
# 6. CloudFront **Access Logging v2** is implemented through AWS CloudWatch Log Delivery services, configured within the
#    'cloudfront/logging.tf' file. This approach offers enhanced flexibility for log destinations (e.g., S3, CloudWatch Logs)
#    and various output formats (e.g., JSON, Parquet), providing robust analytics capabilities.
# 7. Integration with AWS WAF for Layer 7 protection is optional and managed within the 'waf.tf' file.
#    Remember that all CloudFront WAF resources must specify 'scope = "CLOUDFRONT"' and be provisioned via
#    the 'aws.cloudfront' provider.
# 8. Essential S3 bucket details (IDs, ARNs, domain names) required by this module must be exposed as outputs
#    from your S3 module and passed in as input variables.
# 9. Resource tagging adheres to centralized project standards, facilitating efficient resource identification
#    and cost allocation. Note that AWS currently only supports tagging on 'aws_cloudfront_distribution' resources.