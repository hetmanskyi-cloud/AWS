# WAF Configuration for ALB
# This file defines a Web ACL (Access Control List) and its association with the Application Load Balancer (ALB).
# WAF protects ALB from common web vulnerabilities, such as SQL injection or bad bots.

resource "aws_wafv2_web_acl" "alb_waf" {
  # Name of the WAF ACL
  name        = "${var.name_prefix}-alb-waf"
  scope       = "REGIONAL" # Regional WAF for use with ALB (as opposed to global for CloudFront)
  description = "WAF for ALB to protect against basic attacks"

  # Default action if no rules match
  default_action {
    allow {} # Default action is to allow requests
  }

  # Managed rule: Block bad bots
  rule {
    name     = "BlockBadBots" # Name of the rule
    priority = 1              # Priority of this rule

    action {
      block {} # Block requests matching this rule
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet" # Managed rule group provided by AWS
        vendor_name = "AWS"                              # AWS is the vendor for this rule group
      }
    }

    # Visibility settings for monitoring
    visibility_config {
      cloudwatch_metrics_enabled = true           # Enable CloudWatch metrics for this rule
      metric_name                = "BlockBadBots" # Name for the metric
      sampled_requests_enabled   = true           # Enable sampling of requests for analysis
    }
  }

  # Visibility configuration for the entire WAF
  visibility_config {
    cloudwatch_metrics_enabled = true      # Enable CloudWatch metrics for the Web ACL
    metric_name                = "ALB-WAF" # Metric name for the WAF
    sampled_requests_enabled   = true      # Enable sampling of requests for monitoring
  }

  # Tags for identifying resources in AWS Console
  tags = {
    Name        = "${var.name_prefix}-alb-waf"
    Environment = var.environment
  }
}

# Association of the WAF with the ALB
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  # The ARN of the ALB to associate with this WAF
  resource_arn = aws_lb.application.arn
  # The ARN of the WAF ACL
  web_acl_arn = aws_wafv2_web_acl.alb_waf.arn
}
