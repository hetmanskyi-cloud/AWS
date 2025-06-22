# --- WAF (Web Application Firewall) Configuration for ALB --- #

# --- Security Reminder --- #
# - This WAF acts as the SECONDARY, application-level security layer in a defense-in-depth strategy.
# - Its primary role is to ensure traffic originates only from CloudFront and to apply stricter, targeted rules.
# - The PRIMARY, edge-level WAF is configured on the CloudFront distribution.

# --- Notes on ALB Protection --- #
# By default, ALB is protected by AWS Shield Standard (L3/L4).
# This WAF adds critical L7 protection, working in tandem with the CloudFront WAF to create a robust, multi-layered security posture.

# Web ACL (Access Control List) protects the ALB from direct access and applies fine-grained rules.
# This configuration is designed to be highly effective and demonstrate advanced security concepts.
resource "aws_wafv2_web_acl" "alb_waf" {
  count = var.enable_alb_waf ? 1 : 0

  # Name of the WAF ACL
  name        = "${var.name_prefix}-alb-waf-${var.environment}" # Unique name for the WAF ACL
  scope       = "REGIONAL"                                      # Scope: Regional for ALB (Global is used for CloudFront)
  description = "Secondary WAF for ALB to enforce CloudFront-only access and apply app-level rules"

  # Default Action
  # Default action is to allow all requests if no rules match.
  # This is safe because our rules are designed to explicitly block unauthorized or malicious traffic.
  default_action {
    allow {}
  }

  # Rule 1: Enforce Traffic Through CloudFront
  # This is the most critical rule for this WAF. It blocks any request that does not
  # contain the secret custom header added by our CloudFront distribution.
  # This effectively prevents attackers from bypassing our primary CloudFront WAF.
  rule {
    name     = "EnforceCloudFrontOnlyAccess"
    priority = 1 # Highest priority to process this first

    action {
      block {} # Block requests that do not contain the secret header
    }

    statement {
      not_statement {
        statement {
          byte_match_statement {
            search_string         = var.cloudfront_to_alb_secret_header_value # A secret value passed from variables
            positional_constraint = "EXACTLY"
            field_to_match {
              single_header {
                name = "x-custom-origin-verify" # The custom header name
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "EnforceCloudFrontOnly"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Stricter Rate Limiting Rule
  # This rule applies a tighter rate limit than the CloudFront WAF. It acts as a second
  # filter for traffic that has already passed the edge, catching suspicious application-level
  # activity that is not aggressive enough to be caught by the primary WAF.
  rule {
    name     = "StricterRateLimitRule"
    priority = 10 # Lower priority, runs after the CloudFront verification rule

    action {
      block {} # Block requests exceeding the rate limit
    }

    statement {
      rate_based_statement {
        limit              = 1000 # A stricter limit (e.g., 1000 requests per 5 minutes)
        aggregate_key_type = "IP" # Aggregate requests by IP address
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "StricterRateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Visibility Configuration
  # Enable detailed logging for monitoring WAF activity.
  visibility_config {
    cloudwatch_metrics_enabled = true      # Enable detailed metrics
    metric_name                = "ALB-WAF" # Metric name for the WAF
    sampled_requests_enabled   = true      # Enable sampled request logging
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-waf-${var.environment}"
  })

  # Ensure WAF is created after ALB to prevent dependency issues
  depends_on = [aws_lb.application]
}

# --- WAF Association with ALB --- #
# Associates the WAF with the ALB to protect incoming traffic.
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  count = var.enable_alb_waf ? 1 : 0

  # The ARN of the ALB to associate with this WAF
  resource_arn = aws_lb.application.arn
  # The ARN of the WAF ACL
  web_acl_arn = aws_wafv2_web_acl.alb_waf[0].arn
}

# --- ALB WAF Logging Configuration --- #
# Logs all WAF activity to the specified destination via Firehose.
# WAF logging fully depends on Firehose. Logging will fail if Firehose is not enabled and configured properly.
resource "aws_wafv2_web_acl_logging_configuration" "alb_waf_logs" {
  count = (var.enable_alb_waf_logging && var.enable_alb_firehose) ? 1 : 0

  # Note: WAF logging depends on both `enable_waf_logging` and `enable_firehose`.
  # If Firehose is disabled, logging will not function even if WAF is enabled.
  # Ensure `enable_firehose = true` when enabling WAF logging.

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.firehose_alb_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.alb_waf[0].arn

  depends_on = [
    aws_kinesis_firehose_delivery_stream.firehose_alb_waf_logs,
    aws_wafv2_web_acl.alb_waf
  ]
}

# --- Notes --- #
# 1. WAF resources are controlled by `enable_alb_waf` variable.
# 2. Current Configuration (Defense-in-Depth):
#    - "EnforceCloudFrontOnlyAccess": Ensures the ALB only accepts traffic processed by CloudFront, preventing WAF bypass.
#    - "StricterRateLimitRule": Applies a tighter rate limit than the edge WAF, acting as a more sensitive filter.
# 3. Logging:
#    - Enabled only if `enable_alb_waf_logging` and `enable_alb_firehose` variables are both set to `true`.
#    - WAF logging also requires Firehose to be enabled and configured correctly.
# 4. Recommendations for Production:
#    - This two-layer WAF architecture is a strong production pattern.
#    - Most managed rules (OWASP, etc.) are best placed on the CloudFront WAF for efficiency.
#    - This ALB WAF can be extended with highly specific application-level rules if needed in the future.
# 5. IAM Permissions:
#    - Ensure the Terraform execution role has the necessary WAF permissions (wafv2:*, etc.).
