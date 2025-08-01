# --- Data Source to get the public IP of the machine running Terraform --- #
# This fetches the current public IP address to add it to the WAF whitelist.
data "http" "my_ip" {
  # This data source fetches the public IP of the machine running Terraform.
  url = "https://ipv4.icanhazip.com"
}

# --- AWS WAF Web ACL for CloudFront (us-east-1) --- #
# This resource creates an AWS WAFv2 Web Access Control List (Web ACL) for CloudFront,
# acting as the primary, edge security layer. It protects both the WordPress application
# origin (forwarded to ALB) and the media origin (S3) from common web threats.
# All WAF resources for CloudFront must be deployed in the us-east-1 region.

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  provider = aws.cloudfront
  # Create WAF Web ACL only if CloudFront WAF is enabled in variables.
  count = var.enable_cloudfront_waf ? 1 : 0

  name        = "${var.name_prefix}-cloudfront-waf-${var.environment}"
  description = "Primary Edge WAF protecting CloudFront origins: ALB and S3"
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
  # Rules are processed in order of their priority (lower number = higher precedence).

  # Rule 1 & 2: AWS Managed Rules (Baseline Protection)
  # These provide broad protection against common exploits like SQLi, XSS, and known bad inputs.
  # Placing them at the edge (CloudFront) is most efficient as it blocks attacks before they reach the origin (ALB/EC2).
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Rules for WordPress
  # This is the recommended approach for protecting WordPress. It contains rules that
  # block request patterns associated with the exploitation of vulnerabilities specific to WordPress sites.
  # This replaces the need for most custom WordPress rules.
  rule {
    name     = "AWSManagedRulesWordPressRuleSet"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesWordPressRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesWordPressRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Generic rate-based rule to mitigate DDoS and excessive requests.
  # This acts as a general catch-all for other parts of the site. It has a higher limit
  # than the ALB WAF, acting as the first layer of rate-based protection.
  rule {
    name     = "GenericRateLimit"
    priority = 100 # Processed last, before default allow action
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000 # Max requests per 5-minute period per IP
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GenericRateLimitMetrics"
      sampled_requests_enabled   = true
    }
  }

  # --- Rule 5: Block Admin Panel Access (VPN Whitelist) --- #
  # This dynamic rule is created only if both CloudFront WAF and Client VPN are enabled.
  # It blocks all access to the /wp-admin/ path, except for traffic originating from
  # the IP addresses specified in the VPN IP Set.
  dynamic "rule" {
    for_each = var.enable_cloudfront_waf && var.enable_client_vpn ? [1] : []

    content {
      name     = "BlockAdminPanelAccessViaVPNWhitelist"
      priority = 1 # Highest priority, processed first.

      action {
        block {} # Block the request if the conditions below are met.
      }

      statement {
        # This AND statement requires both nested statement blocks to be true.
        and_statement {
          # Condition 1: The request URI starts with /wp-admin/
          statement {
            byte_match_statement {
              search_string = "/wp-admin/"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "NONE"
              }
              positional_constraint = "STARTS_WITH"
            }
          }
          # Condition 2: The source IP is NOT in our VPN IP Set.
          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.vpn_access_ips[0].arn
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockAdminPanelAccessViaVPNWhitelist"
        sampled_requests_enabled   = true
      }
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
  count = var.enable_cloudfront_waf && var.enable_cloudfront_firehose && local.enable_cloudfront_media_distribution && var.logging_bucket_enabled ? 1 : 0

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.firehose_cloudfront_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront_waf[0].arn
}

# --- IP Set for VPN Access --- #
# This IP Set will contain the egress IP addresses of the Client VPN endpoint.
# It is used in a WAF rule to grant exclusive access to whitelisted IPs.
resource "aws_wafv2_ip_set" "vpn_access_ips" {
  provider = aws.cloudfront
  # Create this resource only if both CloudFront WAF and Client VPN are enabled.
  count = var.enable_cloudfront_waf && var.enable_client_vpn ? 1 : 0

  name               = "${var.name_prefix}-vpn-access-ips-${var.environment}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = concat(var.vpn_egress_cidrs, ["${chomp(data.http.my_ip.response_body)}/32"])

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpn-access-ips-${var.environment}"
  })
}

# --- Notes --- #
# 1. This file defines the AWS WAFv2 Web ACL that protects your CloudFront distribution.
# 2. This WAF acts as the **primary, edge security layer**, filtering traffic before it reaches any origin (ALB or S3).
# 3. The WAF on the ALB (defined in the alb module) acts as a **second, application-level security layer**, providing defense-in-depth.
#    There is no duplication, but rather a strategic layering of security controls.
# 4. AWS Managed Rule Groups (priorities 10, 20) efficiently block common attacks (SQLi, XSS, etc.) at the edge.
# 5. The AWSManagedRulesWordPressRuleSet (priority 30) provides specialized protection for WordPress-specific threats,
#    eliminating the need for most custom WordPress rules.
# 6. The generic RateLimit rule (priority 100) acts as a catch-all DDoS mitigation for all traffic.
