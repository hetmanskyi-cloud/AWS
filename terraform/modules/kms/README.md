# AWS KMS Terraform Module

Terraform module to create and manage a general-purpose AWS KMS (Key Management Service) key. It provides secure encryption for AWS resources, supports automatic key rotation, IAM-managed administrative roles, and integrates with CloudWatch for monitoring key usage.

## Overview

This module provisions a KMS key designed for encrypting various AWS resources, supporting cross-region replication, customizable permissions, and monitoring through CloudWatch.

### Supported AWS Resource Encryption:
- CloudWatch Logs
- S3 buckets
- RDS instances
- ElastiCache clusters
- VPC Flow Logs
- SSM parameters and sessions
- EC2 EBS volumes
- WAFv2 logging
- Optional support for:
  - DynamoDB
  - Kinesis Firehose
  - WAF (legacy logging)

## Requirements

| Name         | Version   |
|--------------|-----------|
| Terraform    | >= 1.11   |
| AWS Provider | >= 5.9    |

## Module Architecture

The module provisions:
- **Primary KMS Key** for general encryption purposes.
- **Optional Replica KMS Key** for cross-region S3 replication.
- **IAM Role and Policy** for administrative key management (optional).
- **CloudWatch Alarms** for monitoring KMS usage (optional).

## Prerequisites

- **AWS Provider Configuration**:
  - AWS region and account configuration should be defined in the root Terraform block (`providers.tf`).
- **Existing SNS Topic** (required if key monitoring is enabled):
  - SNS topic ARN for alarm notifications.

## Module File Structure

| File             | Description                                                         |
|------------------|---------------------------------------------------------------------|
| `main.tf`        | Defines primary and replica KMS keys, policies, and grants.         |
| `key.tf`         | IAM role and policy for administrative key management.              |
| `metrics.tf`     | CloudWatch alarms for monitoring key usage.                         |
| `variables.tf`   | Input variables and validation rules for customization.             |
| `outputs.tf`     | Module outputs including ARNs and IDs of created resources.         |

## Inputs

| Name                        | Type           | Description                                                 | Default / Required               |
|-----------------------------|----------------|-------------------------------------------------------------|----------------------------------|
| `aws_account_id`            | `string`       | AWS Account ID                                              | **Required**                     |
| `aws_region`                | `string`       | AWS Region                                                  | **Required**                     |
| `replication_region`        | `string`       | AWS Region for replica key (optional)                       | `""` (no replication by default) |
| `name_prefix`               | `string`       | Prefix for naming resources                                 | **Required**                     |
| `environment`               | `string`       | Deployment environment label                                | One of: `dev`, `stage`, `prod`   |
| `enable_key_rotation`       | `bool`         | Enable automatic key rotation                               | `true`                           |
| `additional_principals`     | `list(string)` | Additional IAM principals with KMS access                   | `[]`                             |
| `enable_kms_role`           | `bool`         | Create IAM role for key management                          | `false`                          |
| `enable_key_monitoring`     | `bool`         | Enable CloudWatch monitoring                                | `false`                          |
| `key_decrypt_threshold`     | `number`       | Threshold for decrypt operations alarm                      | `100`                            |
| `sns_topic_arn`             | `string`       | ARN of SNS topic for alarms (required if monitoring enabled)| `""`                             |
| `default_region_buckets`    | `map(object)`  | Configuration for default region S3 buckets                 | `{}`                             |
| `replication_region_buckets`| `map(object)`  | Configuration for replication region S3 buckets             | `{}`                             |
| `enable_dynamodb`           | `bool`         | Allow DynamoDB service usage                                | `false`                          |
| `enable_firehose`           | `bool`         | Allow Kinesis Firehose usage                                | `false`                          |
| `enable_waf_logging`        | `bool`         | Allow WAF logging usage                                     | `false`                          |

## Outputs

| Name                        | Description                                                 |
|-----------------------------|-------------------------------------------------------------|
| `kms_key_arn`               | ARN of the primary KMS key                                  |
| `kms_key_id`                | ID of the primary KMS key                                   |
| `kms_replica_key_arn`       | ARN of the replica KMS key (if created)                     |
| `enable_kms_role`           | Indicates if IAM role for key management was created        |
| `kms_management_role_arn`   | ARN of the IAM role for key management (if created)         |
| `kms_management_policy_arn` | ARN of the IAM policy for key management (if created)       |
| `kms_decrypt_alarm_arn`     | ARN of the CloudWatch decrypt alarm (if created)            |

## Usage Example

```hcl
module "kms" {
  source                = "./modules/kms"

  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  environment           = var.environment
  name_prefix           = var.name_prefix

  enable_key_rotation   = true
  additional_principals = ["arn:aws:iam::${var.aws_account_id}:role/example-role"]

  enable_kms_role       = true
  enable_key_monitoring = true
  key_decrypt_threshold = 100
  sns_topic_arn         = aws_sns_topic.cloudwatch_alarms.arn

  enable_dynamodb       = true
  enable_firehose       = false
  enable_waf_logging    = true

  default_region_buckets = {
    cloudtrail = { enabled = true }
  }

  depends_on = [aws_sns_topic.cloudwatch_alarms]
}
```
## Security
- **Initial root access** granted temporarily for key setup (must be manually revoked after initial setup).
- **IAM role** replaces root account for ongoing administrative management (optional).
- **CloudWatch Alarms** monitor abnormal or unauthorized key usage.

## Best Practices
- **Automatic Key Rotation**: Reduces risk of key compromise.
- **Least Privilege Access**: Limit permissions strictly to necessary IAM roles and AWS services.
- **Environment-specific Keys**: Maintain separate KMS keys per environment (`dev`, `stage`, `prod`).
- **Monitoring**: Actively monitor KMS usage through CloudWatch.

## Integration
Integrates seamlessly with other modules:
- **VPC, ASG, ALB, RDS, S3, ElastiCache Modules**: Encryption at rest for data stored or transmitted by these services.

## Future Improvements

- **Enhanced Policy Flexibility:**  
  Allow finer-grained permissions customization per AWS service and principal.

- **Expanded Monitoring:**  
  Add additional CloudWatch metrics for better anomaly detection and alerting.

- **Automated Policy Management:**  
  Automate the secure removal of initial root access post-setup.

- **Cross-Account Support:**  
  Simplify configuration of cross-account permissions where necessary.

---

For additional details, see [AWS KMS Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html).