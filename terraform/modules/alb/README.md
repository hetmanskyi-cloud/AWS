# AWS Application Load Balancer (ALB) Terraform Module

Terraform module to provision and manage an AWS Application Load Balancer (ALB) with integrated security, monitoring, logging, and Web Application Firewall (WAF) support.

## Overview

This module creates and manages an Application Load Balancer (ALB) in AWS for handling HTTP/HTTPS traffic. It includes comprehensive configurations for monitoring, logging, security, and WAF integration while adhering to Terraform and AWS best practices.

### Key Features:
- **Public-facing ALB** handling HTTP/HTTPS traffic
- **Target Group** configured with advanced health checks and session stickiness
- **Security Group** with controlled inbound/outbound traffic rules
- **CloudWatch Alarms** for performance and error monitoring
- **WAF Integration** for protection against web-layer attacks
- **Kinesis Firehose** for efficient WAF log delivery to S3

## Requirements

| Name         | Version   |
|--------------|-----------|
| Terraform    | >= 1.11   |
| AWS Provider | >= 5.9    |

## Module Architecture

This module provisions:
- **Application Load Balancer (ALB)**
- **ALB Target Group** for backend integration (e.g., Auto Scaling Groups)
- **Security Group** tailored for ALB traffic management
- **Optional HTTPS Listener** (requires valid SSL certificate)
- **AWS WAF** with rate-based rules and conditional logging
- **CloudWatch Alarms** for proactive monitoring
- **Kinesis Firehose** for log processing (conditional)

## Module Files

| **File**             | **Description**                                                |
|----------------------|----------------------------------------------------------------|
| `main.tf`            | ALB, listeners, target group definitions and configurations    |
| `security_group.tf`  | Security Group configuration for ALB                           |
| `waf.tf`             | WAF resources, rules, and logging integration                  |
| `firehose.tf`        | Kinesis Firehose stream and associated IAM roles/policies      |
| `metrics.tf`         | CloudWatch Alarms for monitoring ALB metrics                   |
| `variables.tf`       | Module input variables                                         |
| `outputs.tf`         | Module outputs for integration with other modules              |

## Inputs

| Name                             | Type           | Description                                              | Validation                          |
|----------------------------------|----------------|----------------------------------------------------------|-------------------------------------|
| `aws_region`                     | `string`       | AWS region for resources                                 | Format: `xx-xxxx-x`                 |
| `aws_account_id`                 | `string`       | AWS Account ID for security policies                     | 12-digit numeric string             |
| `name_prefix`                    | `string`       | Prefix for resource names                                | <= 24 chars                         |
| `environment`                    | `string`       | Deployment environment                                   | One of: `dev`, `stage`, `prod`      |
| `public_subnets`                 | `list(string)` | Public subnet IDs for ALB                                | Valid subnet IDs                    |
| `vpc_id`                         | `string`       | VPC ID for ALB                                           | Valid VPC ID                        |
| `certificate_arn`                | `string`       | SSL Certificate ARN for HTTPS listener                   | Required if HTTPS enabled           |
| `enable_https_listener`          | `bool`         | Toggle HTTPS Listener                                    | `true` or `false`                   |
| `enable_alb_access_logs`         | `bool`         | Toggle ALB access logs                                   | `true` or `false`                   |
| `alb_logs_bucket_name`           | `string`       | S3 bucket for ALB logs                                   | Non-empty string or `null`          |
| `logging_bucket_arn`             | `string`       | ARN of S3 bucket for Firehose                            | Non-empty if Firehose enabled       |
| `kms_key_arn`                    | `string`       | KMS key ARN for log encryption                           | Non-empty if Firehose enabled       |
| `enable_firehose`                | `bool`         | Toggle Kinesis Firehose                                  | `true` or `false`                   |
| `enable_waf`                     | `bool`         | Toggle WAF protection                                    | `true` or `false`                   |
| `enable_waf_logging`             | `bool`         | Toggle WAF logging (requires Firehose)                   | `true` or `false`                   |
| `sns_topic_arn`                  | `string`       | SNS topic for CloudWatch Alarms                          | Valid SNS ARN                       |

## Outputs

| **Name**                            | **Description**                                    |
|-------------------------------------|----------------------------------------------------|
| `alb_arn`                           | ARN of the Application Load Balancer               |
| `alb_dns_name`                      | DNS name of the Application Load Balancer          |
| `alb_security_group_id`             | Security Group ID for ALB                          |
| `wordpress_tg_arn`                  | ARN of the Target Group                            |
| `waf_arn`                           | ARN of the WAF Web ACL (if enabled)                |
| `alb_high_request_count_alarm_arn`  | ARN for high request count alarm                   |
| `alb_5xx_errors_alarm_arn`          | ARN for 5XX error alarm                            |
| `alb_target_response_time_alarm_arn`| ARN for target response time alarm                 |
| `alb_unhealthy_host_count_alarm_arn`| ARN for unhealthy targets alarm                    |

## Example Usage

```hcl
module "alb" {
  source                         = "./modules/alb"
  aws_region                     = "eu-west-1"
  aws_account_id                 = "123456789012"
  name_prefix                    = "prod"
  environment                    = "prod"
  public_subnets                 = module.vpc.public_subnet_ids
  vpc_id                         = module.vpc.vpc_id
  enable_https_listener          = true
  certificate_arn                = "arn:aws:acm:eu-west-1:123456789012:certificate/example"
  enable_alb_access_logs         = true
  alb_logs_bucket_name           = "prod-alb-logs"
  logging_bucket_arn             = module.s3.logging_bucket_arn
  kms_key_arn                    = module.kms.kms_key_arn
  enable_firehose                = true
  enable_waf                     = true
  enable_waf_logging             = true
  sns_topic_arn                  = module.monitoring.sns_topic_arn
}
```

## Security
- **HTTPS recommended** for encrypted client communication.
- **WAF** protects against common attacks like rate-limiting and injection.
- **Firehose** delivers encrypted logs securely to S3.
- **CloudWatch alarms** proactively monitor ALB health.

## Security Best Practices
- Enable WAF for ALB protection against common web attacks.
- Store ALB and WAF logs securely with encryption and access restrictions.
- Regularly audit IAM roles, policies, and review WAF and Security Group configurations.
- Configure detailed CloudWatch alarms and notifications.

## Best Practices
- Enable HTTPS Listener with valid SSL certificate.
- Adjust alarm thresholds according to real-world traffic.

## Integration
Integrates with:
- **VPC Module:** Network infrastructure.
- **ASG Module:** Backend instances.
- **KMS Module:** Log encryption.

## Future Improvements
- **Enhanced WAF Rules:** Integrate managed rule sets for comprehensive protection.
- **Advanced Traffic Insights:** Integrate additional CloudWatch metrics for improved monitoring.
- **Automated SSL management:** Integrate automatic SSL certificate rotation.

---

## Useful Resources

- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-best-practices.html)
- [WAF Protection for ALB](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html)
- [CloudWatch Metrics for ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)
- [AWS Managed Rule Groups](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html)
- [Kinesis Firehose for Logging](https://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html)