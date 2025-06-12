# --- CloudFront Distribution for WordPress Media (Test Dev/Stage environment) --- #
# Deploys a CloudFront CDN for WordPress static media files.
# Uses the default CloudFront domain and SSL certificate (no custom domain or ACM required).
# Securely delivers static content from a private S3 bucket using Origin Access Control (OAC).
# Direct public access to the S3 bucket is blocked.

# --- Origin Access Control for S3 (OAC) --- #
# Grants CloudFront permission to fetch objects from the private S3 bucket.
# This OAC is only created if the WordPress media bucket is enabled AND CloudFront for media is enabled.
resource "aws_cloudfront_origin_access_control" "wordpress_media_oac" {
  count                             = var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_cloudfront_enabled ? 1 : 0
  name                              = "${var.name_prefix}-wordpress-media-oac-${var.environment}"
  description                       = "OAC for CloudFront to access WordPress media bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Cache Policy for WordPress Media --- #
# Defines caching rules for WordPress static media files.
# This replaces the deprecated 'forwarded_values' in the cache behavior.
# It ensures efficient caching by not forwarding query strings or cookies for static assets.
resource "aws_cloudfront_cache_policy" "wordpress_media_cache_policy" {
  count       = var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_cloudfront_enabled ? 1 : 0
  name        = "${var.name_prefix}-wordpress-media-cache-policy-${var.environment}"
  comment     = "Cache policy for WordPress media (static files)"
  default_ttl = 86400 # 24 hours (for dev/stage environments)
  max_ttl     = 86400 # 24 hours (for dev/stage environments, matches default_ttl for quicker updates)
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none" # Do not forward cookies
    }
    headers_config {
      header_behavior = "whitelist" # Only forward whitelisted headers
      # Corrected: 'headers' is a block, not a list attribute directly.
      headers {
        items = ["Origin"] # Required for CORS preflight requests
      }
    }
    query_strings_config {
      query_string_behavior = "none" # Do not forward query strings
    }
    enable_accept_encoding_brotli = true # Enable Brotli compression
    enable_accept_encoding_gzip   = true # Enable GZip compression
  }
}

# --- CloudFront Distribution --- #
# Main CloudFront resource.
# Distributes WordPress media (static files) with caching, HTTPS, and OAC.
# This distribution is only created if the WordPress media bucket is enabled AND CloudFront for media is enabled.
resource "aws_cloudfront_distribution" "wordpress_media" {
  count = var.default_region_buckets["wordpress_media"].enabled && var.wordpress_media_cloudfront_enabled ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true

  comment     = "CloudFront distribution for WordPress media (no custom domain, dev/stage only)"
  price_class = "PriceClass_100" # Use "PriceClass_All" for global, "PriceClass_100" for cheaper regional

  # --- S3 Origin Configuration --- #
  origin {
    # Referencing the S3 bucket via its module output
    domain_name              = module.s3.wordpress_media_bucket_regional_domain_name
    origin_id                = "wordpress-media-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.wordpress_media_oac[0].id # Index 0 due to count
  }

  # --- Default Cache Behavior --- #
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"] # Only safe HTTP methods for static content
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "wordpress-media-origin"
    viewer_protocol_policy = "redirect-to-https" # Always use HTTPS (CloudFront provides default SSL)
    compress               = true                # Enable GZip/Brotli compression

    # Use the newly created CloudFront Cache Policy
    cache_policy_id = aws_cloudfront_cache_policy.wordpress_media_cache_policy[0].id
  }

  # --- Viewer Certificate --- #
  # Use default CloudFront SSL certificate (no ACM or custom domain needed).
  # CloudFront provides HTTPS for its default domain.
  viewer_certificate {
    cloudfront_default_certificate = true
    # Using TLSv1.2_2019 for better security.
    # When cloudfront_default_certificate is true, ssl_support_method should NOT be specified.
    minimum_protocol_version = "TLSv1.2_2019"
  }

  # --- Restrictions (Geo) --- #
  restrictions {
    geo_restriction {
      restriction_type = "none" # No geo-restrictions
      locations        = []     # Empty list means no restrictions
    }
  }

  tags = merge(local.common_tags, local.tags_cloudfront, {
    Name = "${var.name_prefix}-wordpress-media-cdn-${var.environment}"
  })

  # --- CloudFront Access Logging (Optional) --- #
  # This block is conditionally enabled based on 'var.enable_cloudfront_access_logging'
  # and will send logs to your central 'logging' S3 bucket.
  dynamic "logging_config" {
    for_each = var.enable_cloudfront_access_logging && var.default_region_buckets["logging"].enabled ? [1] : []
    content {
      include_cookies = false
      # Dynamically set the logging bucket name to the 'logging' bucket from the S3 module.
      bucket = "${module.s3.logging_bucket_id}.s3.amazonaws.com" # Ensure S3 module exports logging_bucket_id
      prefix = "cloudfront-media-logs/"                          # Custom prefix for CloudFront logs within the logging bucket
    }
  }
}

# --- Notes --- #
# 1. This CloudFront distribution works out of the box with the default AWS domain (no need for domain or ACM).
# 2. To enable access for CloudFront, make sure the S3 bucket policy allows read by CloudFront (OAC) only.
#    This policy is managed in the 's3/policies.tf' file and relies on 'var.wordpress_media_cloudfront_distribution_arn'.
# 3. No Route53 record, alias, or custom ACM certificate required with this setup.
# 4. Switch to custom domain + ACM when ready for prod by updating the 'viewer_certificate' block and adding 'aliases'.
# 5. Always restrict public access to the S3 bucket (already done in S3 module).
# 6. The creation of this CloudFront distribution is conditional on both 'default_region_buckets["wordpress_media"].enabled'
#    and 'wordpress_media_cloudfront_enabled' being true, to avoid errors if the origin S3 bucket is not enabled.
# 7. Minimum TLS protocol version updated to TLSv1.2_2019 for improved security.
# 8. CloudFront access logging is conditionally enabled via 'var.enable_cloudfront_access_logging'
#     and points to the central 'logging' S3 bucket, with a dedicated prefix.