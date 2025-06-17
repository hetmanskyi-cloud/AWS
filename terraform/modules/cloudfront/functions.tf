# --- CloudFront Functions for Edge Logic (us-east-1) --- #
# This file defines lightweight JavaScript functions that run at the Edge to
# intercept and modify viewer requests or responses. All CloudFront Functions
# must be provisioned in the us-east-1 region.

# --- Security Headers Function --- #
# This function intercepts viewer responses to inject critical security headers,
# enhancing protection against common web vulnerabilities like XSS and clickjacking.
resource "aws_cloudfront_function" "security_headers_function" {
  provider = aws.cloudfront # Must be in us-east-1

  # Create the function only if the main CloudFront distribution is enabled.
  count = local.enable_cloudfront_media_distribution ? 1 : 0

  name    = "${var.name_prefix}-security-headers-function-${var.environment}"
  runtime = "cloudfront-js-2.0" # Specifies the modern JavaScript runtime environment.
  comment = "Adds essential security headers to viewer responses."
  publish = true # Automatically publish the function, making it available for association.

  # The source code for the function is read from an external file for better maintainability.
  code = file("${path.module}/functions/security_headers.js")
}

# --- Notes --- #
# 1. Purpose and Scope:
#    - This file is dedicated to managing CloudFront Functions, which provide a powerful
#      mechanism for high-performance, low-latency computations at the AWS Edge.
#    - All resources here MUST use the 'aws.cloudfront' provider alias to ensure deployment in 'us-east-1'.
#
# 2. Security Headers Function:
#    - The primary function, 'security_headers_function', enhances application security by
#      enforcing the presence of important HTTP security headers on all responses to the viewer.
#    - This acts as a reliable, centralized enforcement point, independent of the origin's configuration.
#
# 3. Code Management:
#    - The JavaScript code for the function is stored externally in 'functions/security_headers.js'
#      within this module and referenced using the `file()` function. This is a best practice
#      as it separates logic (JS) from infrastructure (HCL) and allows for better version control.
#
# 4. Association:
#    - IMPORTANT: Creating the function here only defines it. To make it active, it must be
#      associated with a cache behavior in the CloudFront distribution. This association
#      is configured in 'main.tf' within the 'default_cache_behavior' block of the
#      'aws_cloudfront_distribution' resource.
#
# 5. Runtime:
#    - The 'cloudfront-js-2.0' runtime is used, which offers a more modern set of ECMA-compliant
#      JavaScript features compared to the legacy '1.0' version.