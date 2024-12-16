# ALB Module for Terraform

This module creates and manages an Application Load Balancer (ALB) in AWS for handling HTTP/HTTPS traffic, complete with monitoring, logging, and security configurations. It is designed for environments like dev, stage, and prod, ensuring best practices for scalability, performance, and security.

---

### Prerequisites

- **AWS Provider Configuration**:
The region and other parameters of the `aws` provider are specified in the `providers.tf` file of the root block.

An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Creates an Application Load Balancer (ALB)**:
  - Handles HTTP and HTTPS traffic.
  - Includes cross-zone load balancing for improved distribution.
  - Deletion protection to prevent accidental deletion (recommended in prod).
- **Target Groups and Listeners**:
  - Automatically creates target groups for routing traffic to backend instances.
  - Configures HTTP listeners for dev environments.
  - Redirects HTTP to HTTPS in stage and prod environments.
- **Access Logging**:
  - Logs ALB access to a dedicated S3 bucket.
  - Configurable log prefix based on environment.
- **WAF Integration**:
  - Protects ALB with managed rules for blocking bad bots, Log4j exploits, SQL injection, XSS, and DoS attacks.
  - Logging for WAF is enabled in prod for compliance.
- **CloudWatch Metrics and Alarms**:
  - Monitors ALB traffic and errors.
  - Sends notifications for high request counts, 5xx errors, and unhealthy targets.

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

## Input Variables

| **Name**                        | **Type**       | **Description**                                                                        | **Default/Required**  |
|---------------------------------|----------------|----------------------------------------------------------------------------------------|-----------------------|
| `environment`                   | `string`       | Environment for the resources (e.g., dev, stage, prod).                                | Required              |
| `name_prefix`                   | `string`       | Name prefix for ALB resources.                                                         | Required              |
| `public_subnets`                | `list(string)` | List of public subnet IDs for ALB placement.                                           | Required              |
| `vpc_id`                        | `string`       | VPC ID for the ALB and target group.                                                   | Required              |
| `alb_sg_id`                     | `string`       | Security Group ID for the ALB.                                                         | Required              |
| `logging_bucket`                | `string`       | S3 bucket name for storing ALB access logs.                                            | Required              |
| `certificate_arn`               | `string`       | ARN of the SSL certificate for HTTPS listener (required in stage and prod).            | Optional              |
| `alb_request_count_threshold`   | `number`       | Threshold for high request count on ALB.                                               | `1000`                |
| `alb_5xx_threshold`             | `number`       | Threshold for 5XX errors on ALB.                                                       | `50`                  |
| `sns_topic_arn`                 | `string`       | ARN of the SNS topic for sending CloudWatch alarm notifications.                       | Required              |

---

## Outputs

| **Name**            | **Description**                                  |
|---------------------|--------------------------------------------------|
| `alb_arn`           | ARN of the Application Load Balancer.            |
| `target_group_arn`  | ARN of the target group.                         |
| `waf_arn`           | ARN of the WAF Web ACL.                          |

---

## Usage Example

```hcl

module "alb" {
  source                  = "./modules/alb"
  environment             = "dev"
  name_prefix             = "dev"
  public_subnets          = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  vpc_id                  = "vpc-0123456789abcdef0"
  alb_sg_id               = "sg-0123456789abcdef0"
  logging_bucket          = "dev-logs-bucket"
  certificate_arn         = "arn:aws:acm:eu-west-1:123456789012:certificate/example"
  alb_request_count_threshold = 5000
  alb_5xx_threshold        = 100
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
}

output "alb_arn" {
  value = module.alb.alb_arn
}

```

## Security Best Practices

1. **WAF Protection**:
   - Managed rules provide automatic protection from common web attacks.
   - Ensure WAF logging is enabled for compliance in production environments.

2. **Access Logging**:
   - Store logs in a secure, centralized S3 bucket for auditing.
   - Enable versioning on the logging bucket to prevent accidental data loss.

3. **SSL/TLS**:
   - Use valid SSL certificates for HTTPS listeners in stage and prod.
   - Regularly rotate SSL certificates to maintain security.

4. **Monitoring**:
   - Set up CloudWatch alarms for traffic anomalies and unhealthy targets.
   - Use SNS notifications to respond to critical issues promptly.

---

### Notes

- In dev environments, HTTPS and WAF are disabled to reduce costs and simplify testing.
- In stage and prod, all security and monitoring features are enabled to ensure production-grade reliability and compliance.

---

### Future Improvements

1. Add support for additional listeners or target groups for complex routing scenarios.
2. Include optional NAT Gateway integration for backend services.
3. Enhance monitoring with custom metrics for ALB performance.

---

### Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

### Useful Resources

- [Amazon ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/index.html)
- [CloudWatch Metrics for ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)

---