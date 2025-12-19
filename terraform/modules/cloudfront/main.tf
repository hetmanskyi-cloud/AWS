# --- CloudFront Distribution for WordPress Application and Media --- #
# This module creates a secure and performant CloudFront CDN to serve both dynamic
# application content from an ALB and static media files from a private S3 bucket.
# All CloudFront-specific resources are deployed using the 'aws.cloudfront' provider (us-east-1).

# --- Locals --- #
# Centralized conditional logic for enabling CloudFront resources.
locals {
  enable_cloudfront_media_distribution = try(var.default_region_buckets["wordpress_media"].enabled, false) && var.wordpress_media_cloudfront_enabled
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

# --- CloudFront Origin Request Policy for ALB --- #
# This policy forwards all necessary headers for WordPress to correctly identify
# the viewer's protocol (HTTPS) and host when behind CloudFront.
resource "aws_cloudfront_origin_request_policy" "wordpress_alb_policy" {
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0
  name     = "${var.name_prefix}-alb-origin-policy-${var.environment}"
  comment  = "Policy to forward headers for WordPress behind CloudFront+ALB"

  headers_config {
    header_behavior = "whitelist"
    headers {
      # Forward all headers needed for protocol/host detection and client IP
      items = [
        "Host",
        "X-Forwarded-For",
        "X-Forwarded-Host",
        "CloudFront-Forwarded-Proto"
      ]
    }
  }

  cookies_config {
    cookie_behavior = "all"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# --- CloudFront Distribution --- #
# Creates a single CloudFront distribution with two origins:
# 1. ALB for the WordPress application (dynamic content).
# 2. S3 for WordPress media (static content).
# Logging is handled separately through CloudWatch Log Delivery in `cloudfront/logging.tf`, ensuring efficient and cost-effective log storage.

# tfsec:ignore:aws-cloudfront-enable-logging
resource "aws_cloudfront_distribution" "wordpress_media" {
  # checkov:skip=CKV_AWS_374:Geo-restriction is an optional feature, not a baseline security requirement.
  # checkov:skip=CKV_AWS_86:False positive. The module uses the modern logging_config, which this check may not recognize. Logging is configured in logging.tf.
  # checkov:skip=CKV_AWS_174:False positive. The viewer_certificate block explicitly sets minimum_protocol_version to TLSv1.2_2021 when an ACM cert is used.
  # checkov:skip=CKV_AWS_310:Origin failover is an advanced HA feature, not a baseline requirement for this architecture.
  # checkov:skip=CKV_AWS_305:Default root object is not applicable here; root traffic is handled by the ALB origin.
  # checkov:skip=CKV2_AWS_32:False positive. The distribution uses appropriate response header policies.
  # checkov:skip=CKV2_AWS_47:WAF and its rules (including for Log4j) are optional and configured per environment.
  provider = aws.cloudfront
  count    = local.enable_cloudfront_media_distribution ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for WordPress App (ALB) and Media (S3)"
  price_class     = var.cloudfront_price_class # Configurable price class (e.g., PriceClass_100 for lower cost, PriceClass_All for global coverage)

  # --- Recommended: Enable HTTP/3 and HTTP/2 for best performance and compatibility --- #
  http_version = "http2and3"

  # --- Origin 1: ALB for WordPress Application --- #
  # This origin points to the Application Load Balancer.
  # It includes the custom header to verify that traffic comes only from CloudFront.
  origin {
    domain_name = var.alb_dns_name # DNS name of your ALB
    origin_id   = "wordpress-app-origin-alb"

    # --- Origin Shield Configuration --- #
    # This block enables an additional caching layer to protect the origin.
    # It is disabled by default and can be enabled by setting 'enable_origin_shield = true'.
    origin_shield {
      enabled              = var.enable_origin_shield
      origin_shield_region = var.aws_region # Must be a region where your origin (ALB) is located.
    }

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
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled

    # Use the custom origin request policy to forward necessary headers for WordPress.
    origin_request_policy_id = local.enable_cloudfront_media_distribution ? aws_cloudfront_origin_request_policy.wordpress_alb_policy[0].id : null

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
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id   = local.enable_cloudfront_media_distribution ? aws_cloudfront_origin_request_policy.wordpress_alb_policy[0].id : null
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
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id   = local.enable_cloudfront_media_distribution ? aws_cloudfront_origin_request_policy.wordpress_alb_policy[0].id : null
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

  # --- Dynamic Viewer Certificate --- #
  # This section conditionally configures the viewer certificate.
  # If a custom ACM certificate ARN is provided, it uses it. Otherwise, it defaults to the CloudFront certificate.

  # This block is created ONLY if a custom ACM certificate is provided.
  dynamic "viewer_certificate" {
    for_each = var.acm_certificate_arn != null ? [1] : []
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  # This block is created ONLY if NO custom ACM certificate is provided.
  dynamic "viewer_certificate" {
    for_each = var.acm_certificate_arn == null ? [1] : []
    content {
      cloudfront_default_certificate = true
      # minimum_protocol_version is managed by CloudFront for the default certificate.
      # The lifecycle block handles ignoring changes to this.
    }
  }

  # The 'aliases' argument is directly populated from the variable.
  # If the list is empty, no aliases are set.
  aliases = var.custom_domain_aliases

  # --- Lifecycle Configuration --- #
  # This block provides meta-arguments to customize Terraform's behavior for this resource,
  # preventing unwanted "diffs" in the plan for specific, known reasons.
  lifecycle {
    ignore_changes = [
      # Ignore perpetual diffs on the 'origin' block. This is a workaround for a
      # Terraform quirk where a sensitive value inside a complex block (like the secret
      # header for the ALB origin) causes a persistent "change" to be detected on every
      # plan, even when no real change has occurred.
      origin,

      # Ignore changes to the minimum TLS protocol version for the default certificate.
      # When using the default *.cloudfront.net certificate, AWS manages the TLS policy.
      # Attempting to manage it via Terraform can cause unnecessary plan diffs.
      viewer_certificate[0].minimum_protocol_version,
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
# 4. Modern Protocol Support: The distribution is configured with 'http_version = "http2and3"', enabling the latest HTTP/3 protocol
#    for clients that support it, while maintaining backward compatibility with HTTP/2 for optimal performance and reduced latency.
# 5. Cache and Headers Strategy:
#    - Application origin (ALB): Uses a combination of two policies for optimal behavior. The AWS-managed "CachingDisabled"
#      policy ensures that dynamic content is not cached. A custom "Origin Request Policy" is used to explicitly forward
#      the necessary headers (`Host`, `X-Forwarded-*`, `CloudFront-Forwarded-Proto`), all cookies, and all query strings
#      to the origin. This combination allows the application to function correctly behind the reverse proxy.
#    - Media origin (S3): Uses a custom optimized policy that excludes cookies and query strings, enables Brotli/GZIP compression,
#      and sets long TTLs for maximum performance.
#    - Security Headers: This distribution uses AWS-managed Response Headers Policies (e.g., "Managed-SecurityHeadersPolicy") attached
#      directly to the cache behaviors. This is a best practice for providing strong, maintenance-free security headers.
# 6. Content-Security-Policy (CSP) Enhancement:
#    - For maximum security against Cross-Site Scripting (XSS) attacks, a real-world production site should implement a strict
#      Content-Security-Policy (CSP). The AWS-managed policy used here does NOT include CSP, as it must be custom-tailored
#      to the specific application, its themes, and plugins.
#    - Implementing a CSP would require creating a CloudFront Function and replacing the 'response_headers_policy_id' with a
#      'function_association' block in the cache behaviors, after careful testing in a staging environment.
# 7. Origin Protocol Security: The ALB origin uses 'origin_protocol_policy = "http-only"'. This is a deliberate and secure architectural
#    choice. CloudFront terminates the viewer's HTTPS connection, and communication to the origin occurs within the secure AWS backbone.
#    The authenticity of requests is guaranteed by the 'x-custom-origin-verify' secret header, which is validated by a WAF rule
#    on the ALB. An alternative 'https-only' policy can be used for end-to-end encryption if required by specific compliance standards.
# 8. Only safe HTTP methods (GET, HEAD, OPTIONS) are permitted for static content, and all HTTP traffic is automatically
#    redirected to HTTPS, enforcing secure communication channels.
#    For dynamic/application content, all necessary HTTP methods are allowed (GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE).
# 9. CloudFront **Access Logging v2** is implemented through AWS CloudWatch Log Delivery services, configured within the
#    'cloudfront/logging.tf' file. This approach offers enhanced flexibility and robust analytics capabilities.
# 10. Integration with AWS WAF for Layer 7 protection is optional and managed within the 'waf.tf' file.
#     All CloudFront WAF resources must specify 'scope = "CLOUDFRONT"' and be provisioned via the 'aws.cloudfront' provider.
# 11. Optional Origin Shield: The module includes a configurable option to enable Origin Shield ('var.enable_origin_shield').
#     This feature adds an extra caching layer to further reduce origin load and is recommended for high-traffic, global applications.
