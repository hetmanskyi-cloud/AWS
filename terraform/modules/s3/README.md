# S3 Module for Terraform

This module creates and manages S3 buckets for various use cases within a project. It includes configurations for encryption, logging, versioning, lifecycle policies, cross-region replication, and access control to ensure security and compliance with best practices.

---

### Prerequisites

- **AWS Provider Configuration**:  
  The `aws` provider configuration, including the region and credentials, must be set in the root block of the Terraform project. An additional provider configuration for replication is required with the alias `aws.replication`.
- **KMS Key**:  
  A KMS key ARN must be provided via the `kms_key_arn` variable for bucket encryption.
- **VPC Configuration**:
  - VPC ID is required for Lambda function deployment via the `vpc_id` variable
  - Private subnet IDs and CIDR blocks are required for Lambda networking
- **SNS Topic**:
  An SNS topic ARN must be provided via `sns_topic_arn` for notifications and alarms.
- **CORS Configuration**:
  When enabling CORS for WordPress media bucket, configure `allowed_origins` appropriately for your environment.

---

## Features

- **S3 Bucket Management**:
  - **Base buckets**: Always created (scripts, logging, ami)
  - **Special buckets**: Created conditionally (terraform_state, wordpress_media, replication)
  - Dynamic bucket creation via the `buckets` variable
  - CORS configuration for WordPress media bucket with configurable origins

- **Logging Configuration**:
  - Centralized logging bucket for all S3 access logs
  - CloudTrail integration for API activity logging in dedicated 'cloudtrail/' prefix
  - Bucket policy configured for secure CloudTrail access
  - Each service writes to its own prefix for organized log management

- **Lifecycle Management**:
  - Configurable versioning per bucket via `enable_versioning`
  - Automatic cleanup of noncurrent versions after specified retention period
  - Incomplete multipart upload cleanup
  - DynamoDB TTL for state locks with Lambda automation
  - Dead Letter Queue (DLQ) for failed Lambda events

- **Conditional Resource Creation**:
  - DynamoDB Table: Created when terraform_state bucket is enabled via `enable_dynamodb`
  - Lambda Function: Created when enabled via `enable_lambda` (requires DynamoDB)
  - CORS: Enabled via `enable_cors` for WordPress media bucket
  - Replication: Enabled via `enable_s3_replication` for specified buckets

- **Encryption and Security**:
  - Mandatory KMS encryption for all buckets
  - Enforced HTTPS-only access
  - Public access blocked by default
  - VPC endpoints for secure Lambda communication
  - Private subnet isolation for Lambda functions

- **Monitoring and Alerting**:
  - CloudWatch alarms for Lambda errors with SNS notifications
  - Configurable Lambda log retention (default: 30 days)
  - Centralized logging bucket with proper access controls
  - Lambda CloudWatch logs with error tracking
  - DLQ monitoring for failed events

- **Cross-Region Replication**:
  - Optional replication to specified region (us-east-1 or eu-west-1)
  - Supports disaster recovery scenarios
  - IAM roles and policies for secure replication
  - Replication status monitoring

- **DynamoDB Integration**:
  - State locking table with automatic TTL cleanup
  - Point-in-time recovery enabled by default
  - Stream processing via Lambda for TTL management
  - Cost-effective pay-per-request billing mode
  - Secure access through VPC endpoints

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

| **Name**                           | **Type**      | **Description**                                          | **Default**           |
|------------------------------------|---------------|----------------------------------------------------------|-----------------------|
| `replication_region`               | `string`      | Region for replication (us-east-1 or eu-west-1)          | Required              |
| `environment`                      | `string`      | Environment (dev, stage, prod)                           | Required              |
| `name_prefix`                      | `string`      | Resource name prefix                                     | Required              |
| `aws_account_id`                   | `string`      | AWS Account ID                                           | Required              |
| `kms_key_arn`                      | `string`      | KMS key ARN for encryption                               | Required              |
| `sns_topic_arn`                    | `string`      | SNS topic ARN for notifications                          | Required              |
| `vpc_id`                           | `string`      | VPC ID for Lambda deployment                             | Required              |
| `private_subnet_ids`               | `list(string)`| List of private subnet IDs for Lambda                    | Required              |
| `private_subnet_cidr_blocks`       | `list(string)`| CIDR blocks of private subnets                           | Required              |
| `buckets`                          | `map(bool)`   | Map of buckets to create                                 | `{}`                  |
| `enable_versioning`                | `map(bool)`   | Map of buckets with versioning                           | `{}`                  |
| `enable_s3_replication`            | `bool`        | Enable cross-region replication                          | `false`               |
| `enable_lambda`                    | `bool`        | Enable Lambda function                                   | `false`               |
| `enable_dynamodb`                  | `bool`        | Enable DynamoDB table                                    | `false`               |
| `enable_cors`                      | `bool`        | Enable CORS for WordPress media                          | `false`               |
| `allowed_origins`                  | `list(string)`| List of allowed origins for CORS                         |`"https://example.com"`|
| `lambda_log_retention_days`        | `number`      | Days to retain Lambda logs                               | `30`                  |
| `noncurrent_version_retention_days`| `number`      | Days to retain old versions                              | Required              |

---

## Outputs

| **Name**                          | **Description**                                          |
|----------------------------------|-----------------------------------------------------------|
| `scripts_bucket_arn`             | ARN of scripts bucket                                     |
| `scripts_bucket_id`              | ID of scripts bucket                                      |
| `scripts_bucket_name`            | Name of scripts bucket                                    |
| `logging_bucket_arn`             | ARN of logging bucket                                     |
| `logging_bucket_id`              | ID of logging bucket                                      |
| `logging_bucket_name`            | Name of logging bucket                                    |
| `ami_bucket_arn`                 | ARN of AMI bucket                                         |
| `ami_bucket_id`                  | ID of AMI bucket                                          |
| `ami_bucket_name`                | Name of AMI bucket                                        |
| `terraform_state_bucket_arn`     | ARN of Terraform state bucket                             |
| `terraform_state_bucket_id`      | ID of Terraform state bucket                              |
| `terraform_state_bucket_name`    | Name of Terraform state bucket                            |
| `wordpress_media_bucket_arn`     | ARN of WordPress media bucket                             |
| `wordpress_media_bucket_id`      | ID of WordPress media bucket                              |
| `wordpress_media_bucket_name`    | Name of WordPress media bucket                            |
| `replication_bucket_arn`         | ARN of replication bucket                                 |
| `replication_bucket_id`          | ID of replication bucket                                  |
| `replication_bucket_name`        | Name of replication bucket                                |
| `deploy_wordpress_script_etag`   | ETag of the WordPress deployment script                   |
| `s3_encryption_status`           | Map of bucket encryption statuses                         |
| `all_bucket_arns`                | Consolidated list of all bucket ARNs in the module        |

---

## Security Best Practices

- **Access Control**:
  - All buckets are private by default
  - HTTPS-only access enforced
  - VPC endpoints for secure Lambda access
  - Private subnet isolation for Lambda
  - Least privilege IAM policies

- **Encryption**:
  - Mandatory KMS encryption for all resources
  - Encryption enforced via bucket policies
  - Server-side encryption for all objects
  - Secure key management with KMS

- **Monitoring**:
  - CloudWatch alarms for Lambda errors
  - SNS notifications for incidents
  - Centralized logging with retention
  - DLQ for failed events
  - Point-in-time recovery for DynamoDB

- **Cost Optimization**:
  - Pay-per-request billing for DynamoDB
  - Lifecycle policies for old versions
  - Configurable log retention periods
  - Bucket key enabled for KMS optimization

---

## Future Improvements

- Add support for additional replication regions beyond us-east-1 and eu-west-1
- Implement S3 Object Lock for enhanced data protection
- Add support for S3 Access Points
- Implement cross-account access patterns
- Add support for S3 Batch Operations
- Implement automatic bucket policy validation
- Add support for S3 event notifications to additional targets
- Implement automatic backup verification
- Add support for S3 Storage Lens
- Enhanced cost allocation tagging

---

### Useful Resources

- [Amazon S3 Documentation](https://docs.aws.amazon.com/s3/index.html)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/index.html)
- [Lambda VPC Access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [S3 Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)