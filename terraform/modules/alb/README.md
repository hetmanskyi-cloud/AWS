# ALB Module for Terraform

This module creates and manages an Application Load Balancer (ALB) in AWS for handling HTTP/HTTPS traffic. It includes comprehensive configurations for monitoring, logging, and security while adhering to Terraform and AWS best practices.

---

### Prerequisites

- **AWS Provider Configuration**:
  The AWS provider, including the region and credentials, should be configured in the root block's `providers.tf` file.

  Example provider configuration:
  ```hcl
  provider "aws" {
    region = "eu-west-1"
  }
  ```

---

## Features

- **Application Load Balancer**:
  - Handles HTTP and HTTPS traffic (cross-zone load balancing enabled by default).
  - Deletion protection to prevent accidental deletion.
  - Configurable idle timeout and IP address type.
  - Automatically drops invalid HTTP headers for better security (drop_invalid_header_fields = true).
- **Target Groups**:
  - Automatically creates target groups for backend traffic routing.
  - Includes stickiness, slow start, and deregistration delay configurations.
- **Listeners**:
  - HTTP listener always enabled.
  - Optional HTTPS listener with configurable SSL certificate.
  - Supports HTTP-to-HTTPS redirection when HTTPS is enabled.
- **Access Logging**:
  - ALB access logs are delivered to an S3 bucket with configurable prefixes.
- **WAF Integration**:
  - Protects ALB with managed rules for SQL injection, XSS, bad bots, DoS attacks, and Log4j exploits.
  - Optional Firehose integration for WAF logs with KMS encryption.
- **CloudWatch Monitoring**:
  - Includes alarms for high request count, 5xx errors, unhealthy targets, response time anomalies, and health check failures.
  - Notifications via SNS.

---

## Files Structure

| **File**           | **Description**                                                                          |
|--------------------|------------------------------------------------------------------------------------------|
| `main.tf`          | Creates the ALB, target groups, and listeners for HTTP and HTTPS traffic.                |
| `security_group.tf`| Defines security groups for ALB.                                                         |
| `waf.tf`           | Configures WAF with managed rules for security.                                          |
| `firehose.tf`      | Configures Firehose for WAF logging.                                                     |
| `metrics.tf`       | Defines CloudWatch alarms for monitoring ALB activity.                                   |
| `variables.tf`     | Declares input variables for the module.                                                 |
| `outputs.tf`       | Exposes key outputs for integration with other modules.                                  |

---

## **Input Variables**

| **Name**                            | **Type**       | **Description**                                                                          | **Default/Required**|
|-------------------------------------|----------------|------------------------------------------------------------------------------------------|---------------------|
| `name_prefix`                       | `string`       | Prefix for naming resources for easier organization (max 24 characters).                 | Required            |
| `environment`                       | `string`       | Environment for the resources (must be dev, stage, or prod).                             | Required            |
| `public_subnets`                    | `list(string)` | List of public subnet IDs for ALB placement.                                             | Required            |
| `vpc_id`                            | `string`       | VPC ID for the ALB and target group.                                                     | Required            |
| `logging_bucket`                    | `string`       | S3 bucket name for storing ALB access logs.                                              | Required            |
| `logging_bucket_arn`                | `string`       | ARN of the S3 bucket for ALB logs.                                                       | Required            |
| `kms_key_arn`                       | `string`       | KMS key ARN for log encryption.                                                          | Required            |
| `target_group_port`                 | `number`       | Port for the target group (default: 80).                                                 | `80`                |
| `certificate_arn`                   | `string`       | ARN of the SSL certificate for HTTPS listener (required if enable_https_listener = true).| Optional            |
| `alb_request_count_threshold`       | `number`       | Threshold for high request count on ALB.                                                 | `1000`              |
| `alb_5xx_threshold`                 | `number`       | Threshold for 5XX errors on ALB.                                                         | `50`                |
| `sns_topic_arn`                     | `string`       | ARN of the SNS topic for CloudWatch alarm notifications.                                 | Required            |
| `enable_https_listener`             | `bool`         | Enable or disable the creation of the HTTPS listener.                                    | `false`             |
| `enable_alb_access_logs`            | `bool`         | Enable or disable ALB access logs.                                                       | `false`             |
| `enable_waf`                        | `bool`         | Enable or disable WAF for ALB.                                                           | `false`             |
| `enable_waf_logging`                | `bool`         | Enable or disable WAF logging. Requires Firehose to be enabled.                          | `false`             |
| `enable_firehose`                   | `bool`         | Enable or disable Firehose and related resources.                                        | `false`             |
| `enable_high_request_alarm`         | `bool`         | Enable or disable CloudWatch alarm for high request count.                               | `false`             |
| `enable_5xx_alarm`                  | `bool`         | Enable or disable CloudWatch alarm for HTTP 5xx errors.                                  | `false`             |
| `enable_health_check_failed_alarm`  | `bool`         | Enable or disable CloudWatch alarm for ALB health check failures.                        | `false`             |
| `enable_target_response_time_alarm` | `bool`         | Enable or disable CloudWatch alarm for Target Response Time.                             | `false`             |
| `alb_enable_deletion_protection`    | `bool`         | Enable or disable deletion protection for ALB.                                           | `false`             |

---

## **Outputs**

| **Name**                            | **Description**                                       |
|-------------------------------------|-------------------------------------------------------|
| `alb_arn`                           | ARN of the Application Load Balancer.                 |
| `alb_dns_name`                      | DNS name of the Application Load Balancer.            |
| `alb_name`                          | Name of the Application Load Balancer.                |
| `wordpress_tg_arn`                  | ARN of the Target Group for WordPress.                |
| `alb_access_logs_bucket`            | S3 bucket for ALB access logs.                        |
| `alb_access_logs_prefix`            | Prefix for ALB access logs.                           |
| `waf_arn`                           | ARN of the WAF Web ACL.                               |
| `alb_high_request_count_alarm_arn`  | ARN of the CloudWatch alarm for high request count.   |
| `alb_5xx_errors_alarm_arn`          | ARN of the CloudWatch alarm for HTTP 5xx errors.      |
| `alb_target_response_time_alarm_arn`| ARN of the CloudWatch alarm for target response time. |
| `alb_health_check_failed_alarm_arn` | ARN of the CloudWatch alarm for health check failures.|
| `alb_unhealthy_host_count_alarm_arn`| ARN of the CloudWatch alarm for unhealthy targets.    |

---

## Usage Example

```hcl
module "alb" {
  source                             = "./modules/alb"
  name_prefix                        = "dev"
  environment                        = "dev"
  public_subnets                     = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  vpc_id                             = "vpc-0123456789abcdef0"
  logging_bucket                     = "dev-logs-bucket"
  logging_bucket_arn                 = "arn:aws:s3:::dev-logs-bucket"
  kms_key_arn                        = "arn:aws:kms:eu-west-1:123456789012:key/example"
  certificate_arn                    = "arn:aws:acm:eu-west-1:123456789012:certificate/example"
  alb_request_count_threshold        = 5000
  alb_5xx_threshold                  = 100
  enable_target_response_time_alarm  = true
  enable_health_check_failed_alarm   = true
  sns_topic_arn                      = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  enable_https_listener              = true
  enable_alb_access_logs             = true
  enable_waf                         = true
  enable_waf_logging                 = true
  enable_firehose                    = true
}

output "alb_arn" {
  value = module.alb.alb_arn
}
```

---

## Security Best Practices

1. **WAF Protection**:
   - Use managed rules for automatic protection against common web attacks.
   - Enable WAF logging to monitor and audit web traffic patterns.
2. **Access Logging**:
   - Store ALB logs in a secure, encrypted S3 bucket.
   - Use GZIP compression for storage efficiency.
3. **Monitoring**:
   - Configure CloudWatch alarms to detect anomalies and performance issues.
   - Set up SNS notifications for proactive issue resolution.
   - All alarms use treat_missing_data = "notBreaching" to avoid false positives.
   - Unhealthy host count alarm is always enabled for critical health monitoring.
4. **IAM Policies**:
   - Use least privilege principle for all IAM roles and policies.
   - Regularly review and audit IAM permissions.

---

## Notes

- HTTPS listener creation requires a valid SSL certificate.
- WAF logging requires Firehose to be enabled with an appropriate IAM role and bucket policy.
- Access logs are disabled by default for cost savings but can be enabled as needed.
- ALB metrics and logs provide valuable insights into performance and security.
- S3 bucket policies are configured to allow ALB and WAF logging.
- Ensure bucket policies are audited for compliance before production deployment.

---

## Future Improvements

1. Add support for multiple target groups for advanced routing scenarios.
2. Expand WAF rule configurations for more granular security controls.
3. Integrate ALB monitoring with third-party tools for enhanced observability.
4. Add Amazon Athena integration for querying ALB access logs.

---

## Useful Resources

### AWS Documentation
- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancer-best-practices.html)
- [WAF Protection for ALB](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html)
- [CloudWatch Metrics for ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)

### Security & Compliance
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/latest/best-practices-guide/security-best-practices.html)
- [ALB Access Logging](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)
- [AWS WAF Managed Rules](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html)

### Monitoring & Troubleshooting
- [Troubleshooting ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html)
- [CloudWatch Alarms Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Kinesis Firehose for Logging](https://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html)

### WordPress Specific
- [WordPress on AWS Best Practices](https://aws.amazon.com/blogs/architecture/wordpress-best-practices-on-aws/)
- [Securing WordPress on AWS](https://aws.amazon.com/blogs/architecture/wordpress-best-practices-on-aws-security/)