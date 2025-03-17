# S3 Module for Terraform

This module creates and manages S3 buckets for various use cases within a project. It includes configurations for encryption, logging, versioning, lifecycle policies, cross-region replication, and access control to ensure security and compliance with best practices.

---

### Prerequisites

- **AWS Provider Configuration**:  
  The `aws` provider configuration, including the region and credentials, must be set in the root block of the Terraform project. An additional provider configuration for replication is required with the alias `aws.replication`.
- **KMS Key**:  
  A KMS key ARN must be provided via the `kms_key_arn` variable for bucket encryption. For replication, a `kms_replica_key_arn` can be provided for the destination region.
- **SNS Topic**:  
  An SNS topic ARN must be provided via `sns_topic_arn` for notifications and alarms. For replication, a `replication_region_sns_topic_arn` can be provided.
- **CORS Configuration**:
  When enabling CORS for WordPress media bucket, configure `allowed_origins` appropriately for your environment.

---

## Features

- **S3 Bucket Management**:
  - **Default region buckets**: Created based on the `default_region_buckets` map variable
  - **Replication region buckets**: Created based on the `replication_region_buckets` map variable
  - Dynamic bucket creation with configurable properties (versioning, replication, server access logging)
  - CORS configuration for WordPress media bucket with configurable origins

- **Logging Configuration**:
  - Centralized logging bucket for all S3 access logs
  - CloudTrail integration for API activity logging in dedicated bucket
  - Bucket policy configured for secure log delivery
  - ALB logs bucket with appropriate permissions for Elastic Load Balancing service

- **Lifecycle Management**:
  - Configurable versioning per bucket via bucket configuration
  - Automatic cleanup of noncurrent versions after specified retention period
  - Incomplete multipart upload cleanup
  - DynamoDB TTL for state locks with automatic cleanup
  - Special lifecycle rules for terraform_state bucket to prevent accidental deletion

- **Conditional Resource Creation**:
  - DynamoDB Table: Created when enabled via `enable_dynamodb` (requires terraform_state bucket)
  - CORS: Enabled via `enable_cors` for WordPress media bucket
  - Replication: Enabled for buckets with replication property set to true

- **Encryption and Security**:
  - Mandatory KMS encryption for all buckets (except ALB logs bucket which uses SSE-S3)
  - Enforced HTTPS-only access
  - Public access blocked by default
  - Bucket key enabled for KMS cost optimization

- **Monitoring and Alerting**:
  - SNS notifications for bucket events
  - Centralized logging bucket with proper access controls

- **Cross-Region Replication**:
  - Replication to specified region for eligible buckets
  - IAM roles and policies for secure replication
  - Replication status monitoring
  - Support for KMS encrypted objects

- **DynamoDB Integration**:
  - State locking table with TTL cleanup
  - Point-in-time recovery enabled by default
  - Cost-effective pay-per-request billing mode

---

## Module Files Structure

| **File**          | **Description**                                                                          |
|-------------------|------------------------------------------------------------------------------------------|
| `main.tf`         | Core bucket configurations and notifications setup                                       |
| `dynamodb.tf`     | DynamoDB table for state locking                                                         |
| `lifecycle.tf`    | Lifecycle rules for bucket management                                                    |
| `outputs.tf`      | Module outputs                                                                           |
| `policies.tf`     | Bucket policies, CORS rules, and access controls                                         |
| `replication.tf`  | Cross-region replication configuration and IAM roles                                     |
| `variables.tf`    | Input variables                                                                          |

---

## Input Variables

| **Name**                           | **Type**      | **Description**                                          | **Default**             |
|------------------------------------|---------------|----------------------------------------------------------|-------------------------|
| `aws_region`                       | `string`      | AWS region where resources will be created               | Required                |
| `replication_region`               | `string`      | AWS region for replication bucket                        | Required                |
| `environment`                      | `string`      | Environment (dev, stage, prod)                           | Required                |
| `name_prefix`                      | `string`      | Resource name prefix                                     | Required                |
| `aws_account_id`                   | `string`      | AWS Account ID for bucket policies                       | Required                |
| `kms_key_arn`                      | `string`      | KMS key ARN for encryption                               | Required                |
| `kms_replica_key_arn`              | `string`      | ARN of KMS replica key in replication region             | `null`                  |
| `noncurrent_version_retention_days`| `number`      | Retention days for noncurrent object versions            | Required                |
| `sns_topic_arn`                    | `string`      | ARN of SNS Topic for bucket notifications                | Required                |
| `replication_region_sns_topic_arn` | `string`      | ARN of SNS Topic in replication region                   | `""`                    |
| `default_region_buckets`           | `map(object)` | Config for default AWS region buckets                    | `{}`                    |
| `replication_region_buckets`       | `map(object)` | Config for replication region buckets                    | `{}`                    |
| `enable_s3_script`                 | `bool`        | Enable uploading scripts to S3                           | `false`                 |
| `s3_scripts`                       | `map(string)` | Map of files for scripts bucket upload                   | `{}`                    |
| `enable_cors`                      | `bool`        | Enable CORS for WordPress media bucket                   | `false`                 |
| `allowed_origins`                  | `list(string)`| List of allowed origins for S3 CORS                      |`["https://example.com"]`|
| `enable_dynamodb`                  | `bool`        | Enable DynamoDB for Terraform state locking              | `false`                 |

---

## Outputs

| **Name**                                   | **Description**                                           |
|--------------------------------------------|-----------------------------------------------------------|
| `scripts_bucket_arn`                       | ARN of scripts bucket                                     |
| `scripts_bucket_name`                      | Name of scripts bucket                                    |
| `logging_bucket_arn`                       | ARN of logging bucket                                     |
| `logging_bucket_name`                      | Name of logging bucket                                    |
| `logging_bucket_id`                        | ID of logging bucket                                      |
| `alb_logs_bucket_name`                     | Name of the S3 bucket for ALB logs                        |
| `cloudtrail_bucket_arn`                    | ARN of the CloudTrail S3 bucket                           |
| `cloudtrail_bucket_id`                     | ID of the CloudTrail S3 bucket                            |
| `cloudtrail_bucket_name`                   | Name of the CloudTrail S3 bucket                          |
| `terraform_state_bucket_arn`               | ARN of Terraform state bucket                             |
| `terraform_state_bucket_name`              | Name of Terraform state bucket                            |
| `wordpress_media_bucket_arn`               | ARN of WordPress media bucket                             |
| `wordpress_media_bucket_name`              | Name of WordPress media bucket                            |
| `deploy_wordpress_scripts_files_etags_map` | Map of script file keys to ETags                          |
| `replication_bucket_arn`                   | ARN of replication bucket                                 |
| `replication_bucket_name`                  | Name of replication bucket                                |
| `replication_bucket_region`                | Region of replication bucket                              |
| `terraform_locks_table_arn`                | ARN of DynamoDB table for Terraform state locking         |
| `terraform_locks_table_name`               | Name of DynamoDB table for Terraform state locking        |
| `enable_dynamodb`                          | DynamoDB enabled for state locking                        |

---

## Security Best Practices

- **Access Control**:
  - All buckets are private by default
  - HTTPS-only access enforced
  - Least privilege IAM policies

- **Encryption**:
  - Mandatory KMS encryption for all resources (except ALB logs bucket)
  - Encryption enforced via bucket policies
  - Server-side encryption for all objects
  - Secure key management with KMS
  - Bucket key enabled for cost optimization

- **Monitoring**:
  - SNS notifications for bucket events
  - Centralized logging with retention
  - Point-in-time recovery for DynamoDB

- **Cost Optimization**:
  - Pay-per-request billing for DynamoDB
  - Lifecycle policies for old versions
  - Bucket key enabled for KMS optimization

---

## Usage Example

```hcl
module "s3" {
  source = "./modules/s3"

  # General Configuration
  aws_region       = "eu-west-1"
  replication_region = "us-east-1"
  environment      = "dev"
  name_prefix      = "dev"
  aws_account_id   = "123456789012"
  
  # KMS Configuration
  kms_key_arn      = aws_kms_key.s3_key.arn
  kms_replica_key_arn = aws_kms_key.s3_replica_key.arn
  
  # SNS Configuration
  sns_topic_arn    = aws_sns_topic.s3_notifications.arn
  replication_region_sns_topic_arn = aws_sns_topic.replication_notifications.arn
  
  # Bucket Configuration
  default_region_buckets = {
    scripts = {
      enabled = true
      versioning = true
      server_access_logging = true
    },
    logging = {
      enabled = true
      versioning = false
      server_access_logging = false
    },
    terraform_state = {
      enabled = true
      versioning = true
      server_access_logging = true
    },
    wordpress_media = {
      enabled = true
      versioning = true
      replication = true
      server_access_logging = true
    }
  }
  
  replication_region_buckets = {
    wordpress_media = {
      enabled = true
      versioning = true
      server_access_logging = true
      region = "us-east-1"
    }
  }
  
  # WordPress Configuration
  enable_cors = true
  allowed_origins = ["https://mywordpress.example.com"]
  
  # Script Upload Configuration
  enable_s3_script = true
  s3_scripts = {
    "deploy-wordpress.sh" = "scripts/deploy-wordpress.sh"
  }
  
  # DynamoDB Configuration
  enable_dynamodb = true
  
  # Lifecycle Configuration
  noncurrent_version_retention_days = 30
}
```

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
- [S3 Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)