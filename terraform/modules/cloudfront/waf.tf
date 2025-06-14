# --- AWS WAF Web ACL for CloudFront (us-east-1) --- #
# This resource creates an AWS WAFv2 Web Access Control List (Web ACL)
# specifically designed for integration with CloudFront distributions.
# All WAF resources for CloudFront must be deployed in the us-east-1 region
# and specify 'scope = "CLOUDFRONT"'.

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  provider = aws.cloudfront
  # Create WAF Web ACL only if CloudFront WAF is enabled in variables
  # and the main CloudFront distribution is enabled.
  count = var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution ? 1 : 0

  name        = "${var.name_prefix}-cloudfront-waf-${var.environment}"
  description = "Web ACL for CloudFront distribution protecting WordPress media"
  scope       = "CLOUDFRONT" # Essential for associating with CloudFront distributions
  default_action {
    allow {} # Default action is to allow requests unless explicitly blocked by a rule
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-CloudFrontWAFMetrics-${var.environment}"
    sampled_requests_enabled   = true
  }

  # --- WAF Rules --- #
  # Defines the rules for filtering web requests.
  # Rules are processed in order of their priority (lower number = higher precedence).

  # Rule 1: AWS Managed Rule Group for Common Web Exploits (e.g., SQLi, XSS)
  # Provides baseline protection against common vulnerabilities.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10 # Processed first

    override_action {
      none {} # Allows individual rules within this group to define their action (block/count)
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Optional: Exclude specific rules from this managed group if they cause false positives.
        # For example, to exclude a rule that blocks certain valid requests:
        # excluded_rule {
        #   name = "SizeRestrictions_BODY"
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rule Group for Known Bad Inputs (includes Log4j detection)
  # Essential for protecting against CVE-2021-44228 (Log4Shell) and related exploits.
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20 # Processed after CommonRuleSet, before RateLimit

    override_action {
      none {} # Allows individual rules within this group to define their action
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
        # The Log4j rule is part of this rule set. You can exclude other rules from this group
        # if they are not relevant or cause issues.
        # Example to specifically target Log4j protection within this set:
        # excluded_rule {
        #   name = "Log4JRCE" # If you only want to exclude the Log4j rule
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate-based rule to mitigate brute-force attacks or excessive requests.
  # Blocks requests from an IP address if it exceeds a defined threshold within a 5-minute period.
  rule {
    name     = "RateLimit"
    priority = 30 # Processed after managed rule groups

    action {
      block {} # Block requests that exceed the rate limit
    }

    statement {
      rate_based_statement {
        limit              = 2000 # Max requests per 5-minute period per IP (adjust as needed)
        aggregate_key_type = "IP" # Aggregate requests based on source IP address

        # Optional: You can aggregate on other keys like HTTP header, query argument, etc.
        # Example for aggregating by a custom header:
        # custom_key {
        #   header {
        #     name = "X-Forwarded-For" # Useful if a proxy changes client IP
        #   }
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetrics"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-waf-${var.environment}"
  })
}

# --- AWS WAF Logging Configuration (us-east-1) --- #
# Configures logging for the AWS WAF Web ACL to send security logs to Kinesis Firehose,
# which then delivers them to the specified S3 bucket.
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront_waf_logging" {
  provider = aws.cloudfront
  # Create logging configuration only if WAF and the CloudFront distribution are enabled.
  count = var.enable_cloudfront_waf && local.enable_cloudfront_media_distribution ? 1 : 0

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.cloudfront_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront_waf[0].arn

  # Optional: Configure Redacted Fields to prevent sensitive data from being logged.
  # This is highly recommended for production environments.
  # For example, to redact common sensitive headers:
  # redacted_fields {
  #   field_to_match {
  #     single_header { name = "Authorization" }
  #   }
  #   field_to_match {
  #     single_header { name = "Cookie" }
  #   }
  # }
}

# --- Notes --- #
# 1. This file defines the AWS WAFv2 Web ACL that protects your CloudFront distribution.
# 2. The scope must be set to "CLOUDFRONT" and the provider must be aws.cloudfront (us-east-1).
# 3. A default allow action is set, meaning requests are allowed unless a rule explicitly blocks them.
# 4. Two AWS Managed Rule Groups are included for robust protection:
#    - AWSManagedRulesCommonRuleSet: Protects against common web exploits like SQL injection and XSS.
#    - AWSManagedRulesKnownBadInputsRuleSet: Includes rules for known bad inputs, such as Log4j exploits.
#    These are placed with lower priority numbers (10, 20) to ensure they are evaluated first.
# 5. A RateLimit rule (priority 30) is implemented to mitigate brute-force attacks and denial-of-service attempts
#    by blocking IPs that exceed a specified request threshold within a 5-minute window. Adjust limit as needed.
#    Note: rate_limit_statement must be nested inside a statement block.
# 6. WAF logging is configured to send detailed security logs to the Kinesis Firehose delivery stream
#    defined in firehose.tf. This ensures comprehensive audit trails.
#    Note: The aws_wafv2_web_acl_logging_configuration resource does not support tags directly,
#    so they have been removed.
# 7. CloudWatch metrics for WAF are enabled for real-time visibility into WAF performance,
#    blocked requests, and rule-specific actions.
# 8. Remember to set var.enable_cloudfront_waf = true in your variables to enable these WAF resources.