# --- WAF (Web Application Firewall) Configuration for ALB --- #

# --- Notes on ALB Protection --- #
# By default, ALB is protected by AWS Shield Standard, which defends against DDoS attacks at the 
# Network (L3) and Transport (L4) layers. 
# 
# For application-level (L7) attacks, AWS WAF provides additional protection through managed rules.
# Combining WAF and Shield Standard ensures a comprehensive security strategy for ALB.

# Web ACL (Access Control List) protects ALB from common web vulnerabilities.
# Includes managed rules for blocking bad bots, preventing SQL injections, XSS, Denial-of-Service (DoS) attacks and Log4j exploits.
resource "aws_wafv2_web_acl" "alb_waf" {
  count = var.enable_waf ? 1 : 0
  # Name of the WAF ACL
  name        = "${var.name_prefix}-alb-waf" # # Unique name for the WAF ACL
  scope       = "REGIONAL"                   # Scope: Regional for ALB (Global is used for CloudFront)
  description = "WAF for ALB to protect against basic attacks"

  # --- Notes on Rules --- #
  # Ensure that the WAF rules are updated to include the latest versions.
  # Regularly review managed rules (e.g., AWSManagedRulesBotControlRuleSet, AWSManagedRulesSQLiRuleSet)
  # to ensure they cover emerging threats.

  # --- Default Action --- #
  # Default action is to allow all requests if no rules match.
  # - In case no rules match, allow all incoming requests.
  # - Can be changed to `block {}` for stricter security if required.
  default_action {
    allow {

    }
  }

  # --- Managed Rules --- #
  # Managed rules (e.g., SQLi, XSS, Log4j) help protect against common vulnerabilities.
  # Prioritize rules based on application-specific risks.
  # For production, consider enabling additional rulesets for enhanced security.

  # Rule 1: Block malicious bots
  rule {
    name     = "BlockBadBots"
    priority = 1 # Priority of the rule
    action {
      block {} # Block requests matching this rule
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockBadBots"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Block Log4j exploit attempts
  rule {
    name     = "PreventLog4j"
    priority = 2 # Priority of this rule (executed after BlockBadBots)

    action {
      block {} # Block requests matching this rule
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PreventLog4j"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Prevent SQL Injection attacks
  rule {
    name     = "PreventSQLInjection"
    priority = 3 # Priority of this rule (executed after PreventLog4j)
    action {
      block {} # Block requests matching this rule
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PreventXSS"
      sampled_requests_enabled   = true
    }

  }

  # Rule 4: Prevent Cross-Site Scripting (XSS) attacks
  rule {
    name     = "PreventXSS"
    priority = 4 # Priority of this rule (executed after PreventSQLInjection)
    action {
      block {} # Block requests matching this rule
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCrossSiteScriptingRuleSet"
        vendor_name = "AWS" # AWS is the vendor for this rule group
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PreventXSS"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: Prevent Denial-of-Service (DoS) attacks
  rule {
    name     = "PreventDoS"
    priority = 5 # Priority of this rule (executed after Cross-Site Scripting)

    action {
      block {} # Block requests matching this rule
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PreventDoS"
      sampled_requests_enabled   = true
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

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.alb_waf[0].arn
}

# --- Notes --- #
# 1. WAF resources are controlled by `enable_waf` variable.
# 2. Managed Rules:
#    - "BlockBadBots": Protects from malicious bots targeting the ALB.
#    - "PreventLog4j": Blocks Log4j exploit attempts to ensure compliance.
#    - "PreventSQLInjection": Prevents SQL Injection attacks on the ALB.
#    - "PreventXSS": Prevents Cross-Site Scripting attacks.
#    - "PreventDoS": Protects from Denial-of-Service attacks.
# 3. Logging:
#    - Enabled only if `enable_waf` variable and `enable_waf_logging` variable are both set to `true`.