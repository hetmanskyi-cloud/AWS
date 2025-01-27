# S3 Module for Terraform

This module creates and manages S3 buckets for various use cases within a project. It includes configurations for encryption, logging, versioning, lifecycle policies, cross-region replication, and access control to ensure security and compliance with best practices.

---

### Prerequisites

- **AWS Provider Configuration**:  
  The `aws` provider configuration, including the region and credentials, must be set in the root block of the Terraform project. An additional provider configuration for replication is required with the alias `aws.replication`.
- **KMS Key**:  
  A KMS key ARN must be provided via the `kms_key_arn` variable for bucket encryption.
- **VPC Configuration**:
  VPC ID is required for Lambda function deployment via the `vpc_id` variable.
- **SNS Topic**:
  An SNS topic ARN must be provided via `sns_topic_arn` for notifications and alarms.

---

## Features

- **S3 Bucket Management**:
  - **Base buckets**: Always created (scripts, logging, ami)
  - **Special buckets**: Created conditionally (terraform_state, wordpress_media, replication)
  - Dynamic bucket creation via the `buckets` variable
  - CORS configuration for WordPress media bucket

- **Lifecycle Management**:
  - Configurable versioning per bucket via `enable_versioning`
  - Automatic cleanup of noncurrent versions after specified retention period
  - Incomplete multipart upload cleanup
  - Dead Letter Queue (DLQ) for failed Lambda events

- **Conditional Resource Creation**:
  - DynamoDB Table: Created when terraform_state bucket is enabled
  - Lambda Function: Created when enabled via `enable_lambda`
  - CORS: Enabled via `enable_cors` for WordPress media bucket

- **Encryption and Security**:
  - Mandatory KMS encryption for all buckets
  - Enforced HTTPS-only access
  - Public access blocked by default
  - VPC endpoints for secure Lambda communication

- **Monitoring and Alerting**:
  - CloudWatch alarms for Lambda errors
  - SNS notifications for alarms
  - Centralized logging bucket
  - Lambda CloudWatch logs

- **Cross-Region Replication**:
  - Optional replication to specified region
  - Supports us-east-1 or eu-west-1 as replication regions
  - IAM roles and policies for replication

- **DynamoDB Integration**:
  - State locking table with TTL
  - Point-in-time recovery
  - Stream processing via Lambda
  - Pay-per-request billing mode

---

## Files Structure

| **File**          | **Description**                                                                          |
|-------------------|------------------------------------------------------------------------------------------|
| `main.tf`         | Core bucket configurations and replication setup                                         |
| `access.tf`       | Public access block settings                                                             |
| `dynamodb.tf`     | DynamoDB table for state locking                                                         |
| `encryption.tf`   | KMS encryption configuration                                                             |
| `lambda.tf`       | Lambda function and CloudWatch alarms                                                    |
| `logging.tf`      | Bucket logging configuration                                                             |
| `outputs.tf`      | Module outputs                                                                           |
| `policies.tf`     | Bucket policies and CORS rules                                                           |
| `variables.tf`    | Input variables                                                                          |
| `versioning.tf`   | Bucket versioning configuration                                                          |

---

## Input Variables

| **Name**                            | **Type**    | **Description**                                          | **Default** |
|-------------------------------------|-------------|----------------------------------------------------------|-------------|
| `replication_region`                | `string`    | Region for replication (us-east-1 or eu-west-1)          | Required    |
| `environment`                       | `string`    | Environment (dev, stage, prod)                           | Required    |
| `name_prefix`                       | `string`    | Resource name prefix                                     | Required    |
| `aws_account_id`                    | `string`    | AWS Account ID                                           | Required    |
| `kms_key_arn`                       | `string`    | KMS key ARN for encryption                               | Required    |
| `sns_topic_arn`                     | `string`    | SNS topic ARN for notifications                          | Required    |
| `vpc_id`                            | `string`    | VPC ID for Lambda deployment                             | Required    |
| `buckets`                           | `map(bool)` | Map of buckets to create                                 | `{}`        |
| `enable_versioning`                 | `map(bool)` | Map of buckets with versioning                           | `{}`        |
| `enable_s3_replication`             | `bool`      | Enable cross-region replication                          | `false`     |
| `enable_lambda`                     | `bool`      | Enable Lambda function                                   | `false`     |
| `enable_dynamodb`                   | `bool`      | Enable DynamoDB table                                    | `false`     |
| `enable_cors`                       | `bool`      | Enable CORS for WordPress media                          | `false`     |
| `noncurrent_version_retention_days` | `number`    | Days to retain old versions                              | Required    |

---

## Outputs

| **Name**                     | **Description**                                    |
|------------------------------|----------------------------------------------------|
| `scripts_bucket_arn`         | ARN of scripts bucket                              |
| `logging_bucket_arn`         | ARN of logging bucket                              |
| `ami_bucket_arn`             | ARN of AMI bucket                                  |
| `terraform_state_bucket_arn` | ARN of Terraform state bucket                      |
| `wordpress_media_bucket_arn` | ARN of WordPress media bucket                      |
| `replication_bucket_arn`     | ARN of replication bucket                          |
| `s3_encryption_status`       | Map of bucket encryption statuses                  |
| `all_bucket_arns`            | List of all bucket ARNs                            |

---

## Security Best Practices

- **Access Control**:
  - All buckets are private by default
  - HTTPS-only access enforced
  - VPC endpoints for secure Lambda access

- **Encryption**:
  - Mandatory KMS encryption
  - Encryption enforced via bucket policies
  - Server-side encryption for all objects

- **Monitoring**:
  - CloudWatch alarms for Lambda errors
  - SNS notifications for incidents
  - Centralized logging
  - DLQ for failed events

---

## Future Improvements

- Add support for additional replication regions
- Implement intelligent tiering for cost optimization
- Add support for bucket inventory reports
- Enhance monitoring with custom CloudWatch metrics
- Implement automated log analysis

---

### Useful Resources

- [Amazon S3 Documentation](https://docs.aws.amazon.com/s3/index.html)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/index.html)
- [Lambda VPC Access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [S3 Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)