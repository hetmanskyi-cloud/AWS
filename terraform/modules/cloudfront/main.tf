# --- Terraform Configuration --- #
# Defines the required AWS provider and its version.
# The 'aws.cloudfront' alias is explicitly configured for resources that must reside in us-east-1,
# such as CloudFront distributions, WAF Web ACLs, and related IAM/Firehose/CloudWatch Log Delivery components.
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws,            # Default AWS provider alias
        aws.cloudfront, # Alias for AWS provider configured to us-east-1
      ]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# --- AWS Account Identity Data Source --- #
# This data source retrieves the AWS account ID for use in resource ARNs,
# S3 path constructions, and tagging. It is required for dynamically referencing
# the current AWS account in output variables and policy documents.
data "aws_caller_identity" "current" {}

# --- CloudFront Distribution for WordPress Application and Media --- #
# This module creates a secure and performant CloudFront CDN to serve both dynamic
# application content from an ALB and static media files from a private S3 bucket.
# All CloudFront-specific resources are deployed using the 'aws.cloudfront' provider (us-east-1).

# --- Locals --- #
# Centralized conditional logic for enabling CloudFront resources.
locals {
  enable_cloudfront_media_distribution = can(var.default_region_buckets["wordpress_media"].enabled) && var.wordpress_media_cloudfront_enabled
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

# --- CloudFront Cache Policies --- #

# Data Source for the AWS-Managed CachingDisabled Policy (for WordPress Application)
# This policy forwards all headers, cookies, and query strings, effectively disabling the cache.
# It's used for the dynamic application content to ensure real-time behavior.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  provider = aws.cloudfront
  name     = "Managed-CachingDisabled"
}

# --- CloudFront Cache Policy for WordPress Media (S3 Origin) --- #
# Defines optimal caching behavior for static media, enhancing performance and reducing origin load.
# It disables cookies and query strings, while enabling Brotli and GZIP compression.
resource "aws_cloudfront_cache_policy" "wordpress_media_cache_policy" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  name        = "${var.name_prefix}-wordpress-media-cache-policy-${var.environment}"
  comment     = "Optimized cache policy for WordPress media static files"
  default_ttl = 86400    # 24 hours (default for development/staging; adjust for production)
  max_ttl     = 31536000 # 1 year (recommended for production)
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
# Creates a single CloudFront distribution with two origins:
# 1. ALB for the WordPress application (dynamic content).
# 2. S3 for WordPress media (static content).
# Logging is handled separately through CloudWatch Log Delivery in `cloudfront/logging.tf`, ensuring efficient and cost-effective log storage.

# tfsec:ignore:aws-cloudfront-enable-logging
resource "aws_cloudfront_distribution" "wordpress_media" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for WordPress App (ALB) and Media (S3)"
  price_class     = var.cloudfront_price_class # Configurable price class (e.g., PriceClass_100 for lower cost, PriceClass_All for global coverage)

  # --- Origin 1: ALB for WordPress Application --- #
  # This origin points to the Application Load Balancer.
  # It includes the custom header to verify that traffic comes only from CloudFront.
  origin {
    domain_name = var.alb_dns_name # DNS name of your ALB
    origin_id   = "wordpress-app-origin-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Secret header for the ALB WAF to check
    custom_header {
      name  = "x-custom-origin-verify"
      value = var.cloudfront_to_alb_secret_header_value
    }
  }

  # --- Origin 2: S3 for WordPress Media (Private) --- #
  # This origin points to the private S3 bucket, accessible only via OAC.
  origin {
    domain_name              = var.s3_module_outputs.wordpress_media_bucket_regional_domain_name
    origin_id                = "wordpress-media-origin-s3"
    origin_access_control_id = local.enable_cloudfront_media_distribution ? aws_cloudfront_origin_access_control.wordpress_media_oac[0].id : null
  }

  # --- Default Cache Behavior (for WordPress Application via ALB) --- #
  # This is the primary behavior. All requests that do NOT match a more specific
  # ordered_cache_behavior will be routed to the WordPress application running behind the ALB.
  # This ensures the homepage, posts, pages, and all other standard routes use the dynamic origin.
  default_cache_behavior {
    target_origin_id       = "wordpress-app-origin-alb" # Points to ALB (WordPress App)
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https" # Always use HTTPS
    compress               = true

    # Use the AWS-managed policy to disable caching, forwarding all headers, cookies,
    # and query strings to the application. This is critical for dynamic content.
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    # Use the AWS-managed policy for security headers, suitable for web applications.
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63" # Managed-SecurityHeadersPolicy
  }

  # --- Ordered Cache Behavior (for WordPress Login Page) --- #
  # This rule has the highest precedence to ensure /wp-login.php is always routed
  # directly to the ALB and is never cached.
  ordered_cache_behavior {
    path_pattern           = "/wp-login.php"
    target_origin_id       = "wordpress-app-origin-alb"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Use the same no-cache policy as the default behavior for consistency.
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63" # Managed-SecurityHeadersPolicy
  }

  # --- Ordered Cache Behavior (for WordPress Admin Panel) --- #
  # This rule explicitly routes all /wp-admin/* traffic to the ALB, ensuring the
  # WordPress dashboard functions correctly without being cached.
  ordered_cache_behavior {
    path_pattern           = "/wp-admin/*"
    target_origin_id       = "wordpress-app-origin-alb"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Use the same no-cache policy as the default behavior.
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63" # Managed-SecurityHeadersPolicy
  }

  # --- Ordered Cache Behavior (for WordPress Media Files) --- #
  # This behavior applies to all uploaded media files, routing them to the S3 origin.
  # Static files are efficiently cached at the edge for optimal performance.
  ordered_cache_behavior {
    path_pattern           = "/wp-content/uploads/*"     # Standard path for WordPress media
    target_origin_id       = "wordpress-media-origin-s3" # Points to S3 bucket
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Use the custom-defined cache policy optimized for static media.
    cache_policy_id = local.enable_cloudfront_media_distribution ? aws_cloudfront_cache_policy.wordpress_media_cache_policy[0].id : null

    # Use the AWS-managed policy for CORS and security headers, suitable for S3 origins.
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-CORS-S3Origin
  }

  # --- Viewer Certificate for Custom Domain (Production ACM Integration) --- #
  # To enable a custom domain (e.g., cdn.example.com) with a validated SSL certificate:
  # 1. **Issue ACM certificate** in us-east-1 (N. Virginia). Example: module.acm.acm_certificate_arn
  # 2. **Specify your domain name(s)** in aliases below.
  # 3. **Uncomment this block** and comment out the default 'cloudfront_default_certificate' block.
  # 4. **Set up Route53 alias record** pointing to the CloudFront domain for your distribution.
  #
  # viewer_certificate {
  #   acm_certificate_arn            = var.acm_certificate_arn        # ACM cert ARN (us-east-1 only!)
  #   ssl_support_method             = "sni-only"                     # SNI is recommended
  #   minimum_protocol_version       = "TLSv1.2_2021"                 # Or higher
  # }
  #
  # aliases = [
  #   "cdn.example.com",         # Your custom CDN domain
  #   "media.example.com",       # (Optional) Additional domains
  # ]

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

# --- Notes --- #
# 1. This CloudFront distribution is multi-origin: it serves both dynamic application content from an Application Load Balancer (ALB)
#    and static media files from a private S3 bucket.
#    - The ALB origin delivers WordPress application traffic and is protected by a custom header (enforced by ALB WAF) to prevent direct access.
#    - The S3 origin is locked down and accessible only through CloudFront via Origin Access Control (OAC).
# 2. All CloudFront-related resources (distributions, OACs, cache policies, and associated WAF/Firehose/CloudWatch Log Delivery
#    components) must be provisioned in the us-east-1 region using the 'aws.cloudfront' provider alias.
#    This is a global AWS service requirement, irrespective of your primary AWS region.
# 3. For development and staging environments, the default AWS-managed SSL certificate and CloudFront domain are utilized.
#    For production deployments, it is strongly advised to provision a custom domain name and an AWS Certificate Manager (ACM)
#    certificate in us-east-1, integrated with Route53 alias records for a custom endpoint.
# 4. Cache policy strategy:
#    - **Application origin (ALB)**: Uses the AWS-managed "CachingDisabled" policy, which forwards all headers, cookies, and query strings,
#      and disables caching to ensure real-time application behavior (best practice for dynamic content).
#    - **Media origin (S3)**: Uses a custom optimized policy that excludes cookies and query strings, enables Brotli/GZIP compression,
#      and sets long TTLs for maximum performance.
# 5. Only safe HTTP methods (GET, HEAD, OPTIONS) are permitted for static content, and all HTTP traffic is automatically
#    redirected to HTTPS, enforcing secure communication channels.
#    For dynamic/application content, all necessary HTTP methods are allowed (GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE).
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
