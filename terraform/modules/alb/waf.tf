# --- WAF (Web Application Firewall) Configuration for ALB --- #

# --- Notes on ALB Protection --- #
# By default, ALB is protected by AWS Shield Standard, which defends against DDoS attacks at the 
# Network (L3) and Transport (L4) layers. 
# 
# For application-level (L7) attacks, AWS WAF provides additional protection through managed rules.
# Combining WAF and Shield Standard ensures a comprehensive security strategy for ALB.

# Web ACL (Access Control List) protects ALB from common web vulnerabilities.
# This is a simplified configuration for testing purposes.
resource "aws_wafv2_web_acl" "alb_waf" {
  count = var.enable_waf ? 1 : 0

  # Name of the WAF ACL
  name        = "${var.name_prefix}-alb-waf" # Unique name for the WAF ACL
  scope       = "REGIONAL"                   # Scope: Regional for ALB (Global is used for CloudFront)
  description = "WAF for ALB to protect against basic attacks"

  # --- Default Action --- #
  # Default action is to allow all requests if no rules match.
  # - In case no rules match, allow all incoming requests.
  # - Can be changed to `block {}` for stricter security if required.
  default_action {
    allow {}
  }

  # --- Rate Limiting Rule --- #
  # Simple rate limiting rule to prevent abuse and brute force attacks.
  # Limits requests from a single IP to 1000 requests per 5-minute period.
  rule {
    name     = "RateLimitRule"
    priority = 1 # Priority of the rule

    action {
      block {} # Block requests exceeding the rate limit
    }

    statement {
      rate_based_statement {
        limit              = 1000 # Maximum number of requests allowed in 5 minutes
        aggregate_key_type = "IP" # Aggregate requests by IP address
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true            # Enable CloudWatch metrics
      metric_name                = "RateLimitRule" # Metric name for CloudWatch
      sampled_requests_enabled   = true            # Enable request sampling for detailed analysis
    }
  }

  # --- Visibility Configuration --- #
  # Enable detailed logging for monitoring WAF activity.
  visibility_config {
    cloudwatch_metrics_enabled = true      # Enable detailed metrics
    metric_name                = "ALB-WAF" # Metric name for the WAF
    sampled_requests_enabled   = true      # Enable sampled request logging
  }

  tags = {
    Name        = "${var.name_prefix}-alb-waf"
    Environment = var.environment
  }

  # Ensure WAF is created after ALB to prevent dependency issues
  depends_on = [aws_lb.application]
}

# --- WAF Association with ALB --- #
# Associates the WAF with the ALB to protect incoming traffic.
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  count = var.enable_waf ? 1 : 0

  # The ARN of the ALB to associate with this WAF
  resource_arn = aws_lb.application.arn
  # The ARN of the WAF ACL
  web_acl_arn = aws_wafv2_web_acl.alb_waf[0].arn
}

# --- WAF Logging Configuration --- #
# Logs all WAF activity to the specified destination.
resource "aws_wafv2_web_acl_logging_configuration" "alb_waf_logs" {
  count = (var.enable_waf_logging && var.enable_firehose) ? 1 : 0

  # Note: WAF logging depends on both `enable_waf_logging` and `enable_firehose`.
  # If Firehose is disabled, logging will not function even if WAF is enabled.
  # Ensure `enable_firehose = true` when enabling WAF logging.

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.aws_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.alb_waf[0].arn

  depends_on = [aws_kinesis_firehose_delivery_stream.aws_waf_logs]
}

# --- Notes --- #
# 1. WAF resources are controlled by `enable_waf` variable.
# 2. Current Configuration:
#    - "RateLimitRule": Limits requests from a single IP to prevent abuse.
#    - This is a simplified configuration for testing purposes.
# 3. Logging:
#    - Enabled only if `enable_waf` variable and `enable_waf_logging` variable are both set to `true`.
# 4. Recommendations for Production:
#    - Start with this simplified configuration and test thoroughly
#    - Gradually add AWS Managed Rule Groups in the following order:
#      a. AWSManagedRulesCommonRuleSet - Basic protection against common threats
#      b. AWSManagedRulesSQLiRuleSet - Protection against SQL injection attacks
#      c. AWSManagedRulesCrossSiteScriptingRuleSet - Protection against XSS attacks
#      d. AWSManagedRulesKnownBadInputsRuleSet - Protection against known malicious inputs
#      e. AWSManagedRulesBotControlRuleSet - Protection against bot traffic
#    - Add each rule group individually and test after each addition
#    - Monitor WAF metrics in CloudWatch to evaluate effectiveness
#    - Consider using AWS Firewall Manager for centralized WAF management across multiple accounts
# 5. IAM Permissions:
#    - Ensure the Terraform execution role has the necessary WAF permissions
#    - Required permissions include wafv2:CreateWebACL, wafv2:GetWebACL, wafv2:UpdateWebACL, etc.
#    - For managed rule groups, additional permissions may be required