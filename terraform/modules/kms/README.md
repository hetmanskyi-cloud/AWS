# KMS Module for Terraform

This module creates and manages a KMS (Key Management Service) key in AWS. The key is designed for general encryption purposes, such as securing CloudWatch Logs, S3 buckets, and other resources. It supports automatic key rotation and dynamic configuration of permissions, including optional IAM roles for key management and CloudWatch monitoring.

---

### Prerequisites

- **AWS Provider Configuration**:
  The region and other parameters of the `aws` provider are specified in the `providers.tf` file of the root block.

  An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Creates a KMS Key**:
  - Designed for encrypting various AWS resources including:
    - CloudWatch Logs
    - S3 buckets
    - RDS
    - ElastiCache
    - VPC Flow Logs
    - SSM
    - EC2 (EBS)
    - WAFv2
    - Optional support for:
      - DynamoDB
      - Lambda
      - Kinesis Firehose
      - WAF Logging

- **Customizable Access Policies**:
  - Initial setup with temporary root access for configuration
  - Service-specific permissions through AWS service principals
  - Additional permissions through IAM roles and users via `additional_principals`
  - Flexible S3 bucket permissions through the `buckets` variable

- **Optional IAM Role for Key Management**:
  - Conditional creation of an IAM role and associated policy for administrative management
  - Enables granular control over key management permissions
  - Replaces root-level access for better security and compliance

- **CloudWatch Monitoring**:
  - CloudWatch Alarms for monitoring KMS key usage
  - Configurable thresholds for decrypt operations
  - Notification settings via SNS
  - Conditional creation based on `enable_key_monitoring`

- **Environment-Specific Tags**:
  - Resource name and environment tags (e.g., dev, stage, prod)
  - Consistent tagging for better resource organization
  - Enhanced resource tracking and cost allocation

---

## Files Structure

| **File**         | **Description**                                                                      |
|------------------|--------------------------------------------------------------------------------------|
| `main.tf`        | Creates the KMS key, defines policies, and configures access for services and roles. |
| `variables.tf`   | Declares input variables for the module.                                             |
| `outputs.tf`     | Exposes key outputs for integration with other modules.                              |
| `key.tf`         | Defines the IAM role and policy for managing the KMS key.                            |
| `metrics.tf`     | Configures CloudWatch alarms for monitoring KMS key usage.                           |

---

## Input Variables

| **Name**                | **Type**       | **Description**                                                       | **Default/Required**  |
|-------------------------|----------------|-----------------------------------------------------------------------|-----------------------|
| `aws_account_id`        | `string`       | AWS Account ID for configuring permissions in the KMS key policy      | **Required**          |
| `aws_region`            | `string`       | AWS Region where the resources are created                            | **Required**          |
| `name_prefix`           | `string`       | Name prefix for all resources                                         | **Required**          |
| `environment`           | `string`       | Environment for the resources (e.g., dev, stage, prod)                | **Required**          |
| `enable_key_rotation`   | `bool`         | Enable or disable automatic key rotation for the KMS key              | `true`                |
| `additional_principals` | `list(string)` | List of IAM role/user ARNs to grant access to the KMS key             | `[]`                  |
| `enable_kms_role`       | `bool`         | Enable or disable the creation of an IAM role for KMS management      | `false`               |
| `enable_key_monitoring` | `bool`         | Enable or disable CloudWatch Alarms for monitoring KMS key usage      | `false`               |
| `key_decrypt_threshold` | `number`       | Threshold for KMS decrypt operations to trigger an alarm              | `100`                 |
| `sns_topic_arn`         | `string`       | ARN of the SNS Topic for sending CloudWatch alarm notifications       | `""`                  |
| `buckets`               | `map(bool)`    | Map to enable or disable S3 buckets                                   | `{}`                  |
| `enable_dynamodb`       | `bool`         | Enable permissions for DynamoDB to use the KMS key                    | `false`               |
| `enable_lambda`         | `bool`         | Enable permissions for Lambda to use the KMS key                      | `false`               |
| `enable_firehose`       | `bool`         | Enable permissions for Kinesis Firehose to use the KMS key            | `false`               |
| `enable_waf_logging`    | `bool`         | Enable permissions for WAF logging to use the KMS key                 | `false`               |

---

## Outputs

| **Name**                    | **Description**                                           |
|-----------------------------|-----------------------------------------------------------|
| `kms_key_arn`               | ARN of the KMS encryption key for other resources to use. |
| `kms_key_id`                | ID of the KMS encryption key for other resources to use.  |
| `enable_kms_role`           | Indicates if the IAM role for KMS management was created. |
| `kms_management_role_arn`   | ARN of the IAM role for managing the KMS encryption key.  |
| `kms_management_policy_arn` | ARN of the KMS management policy for managing the key.    |
| `kms_decrypt_alarm_arn`     | The ARN of the CloudWatch Alarm for decrypt operations.   |

---

## Usage Example

```hcl
module "kms" {
  source                = "./modules/kms"

  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  environment           = var.environment
  name_prefix           = var.name_prefix
  
  # Key configuration
  enable_key_rotation   = true
  additional_principals = ["arn:aws:iam::${var.aws_account_id}:role/example-role"]
  
  # IAM role and monitoring
  enable_kms_role       = true                    # Activate after initial setup
  enable_key_monitoring = true
  key_decrypt_threshold = 100
  sns_topic_arn         = aws_sns_topic.cloudwatch_alarms.arn
  
  # Optional service integrations
  enable_dynamodb     = true    # Enable for DynamoDB encryption
  enable_lambda       = true    # Enable for Lambda function encryption
  enable_firehose     = false   # Disable Kinesis Firehose integration
  enable_waf_logging  = true    # Enable for WAF logging encryption
  
  # S3 bucket configurations
  buckets = {
    "my-bucket-1" = true
    "my-bucket-2" = false
  }

  depends_on = [aws_sns_topic.cloudwatch_alarms]
}

output "kms_key_arn" {
  value = module.kms.kms_key_arn
}

output "kms_key_id" {
  value = module.kms.kms_key_id
}
```

---

## Initial Setup

During the initial creation of the KMS key, full access is granted to the AWS account root principal to simplify setup and ensure secure key management. However, it is strongly recommended to update the KMS key policy after initial creation to restrict access and adhere to the principle of least privilege.

1. **Step 1**: Create the key with root permissions using the default settings in this module.
   - The key policy initially includes root access for simplicity and flexibility during setup.
2. **Step 2**: Review the KMS key policy in the Terraform code and remove root access:
   - Remove the policy that grants root access (`"Principal": { "AWS": "arn:aws:iam::<aws_account_id>:root" }`).
   - **Example:**
     ```hcl
     {
       Effect    = "Allow",
       Principal = { AWS = "arn:aws:iam::123456789012:root" },
       Action    = "kms:*",
       Resource  = "<kms_key_arn>"
     }
     ```
   - Update the Terraform configuration with the modified policy and apply changes (`terraform apply`).
3. **Step 3**: Grant specific permissions to IAM roles that require access using the `additional_principals` variable.
4. **Step 4**: Test the updated policy to ensure it meets operational requirements without introducing unnecessary risks.

This step-by-step process ensures secure management of the KMS key while following the principle of least privilege.

---

## Security Best Practices

1. **Key Rotation**:
   Enable automatic key rotation to reduce the risk of compromised encryption keys.

2. **Access Policies**:
   - **During Initial Setup**:
     - Full access is granted to the AWS root account for ease of configuration.
   - **After Setup**:
     - Review and update the key policy to:
       - Remove root access
       - Grant only necessary permissions to IAM roles and services
     - Use the `additional_principals` variable to define specific IAM roles requiring access

3. **Environment Isolation**:
   Use separate KMS keys for each environment (e.g., dev, stage, prod) to maintain resource isolation.

4. **Monitoring**:
   Monitor key usage through AWS CloudWatch Alarms to detect unauthorized access or anomalies.

5. **IAM Role Management**:
   - If `enable_kms_role` is enabled, ensure the IAM role has only necessary permissions to manage the KMS key.
   - Regularly review and audit IAM roles and policies associated with the KMS key.

6. **Recovery Process**:
   - In the event of accidental deletion or loss of access to a key, use AWS support or account root access to recover the key.
   - Regularly back up key metadata and policies for disaster recovery planning.

---

## Future Improvements

1. **Deploy Policy Setup**:
   - Provide more detailed control in the `additional_principals` variable to allow specific actions.
   - Implement separate policy configurations for each integrated service.
   - Add support for custom policy conditions per service.

2. **Enhance Monitoring and Notifications**:
   - Introduce additional metrics for specific services (e.g., S3 encryption operations).
   - Add support for multiple SNS topics with different notification patterns.
   - Implement custom metric filters for better anomaly detection.

3. **Environment-Related Enhancements**:
   - Implement stricter key policies for production environments.
   - Add support for cross-account access patterns.
   - Enhance tag management for better resource tracking.

4. **Service Integration**:
   - Add support for additional AWS services as needed.
   - Implement service-specific encryption contexts.
   - Add support for service-linked roles where applicable.

5. **Security Improvements**:
   - Implement automated key policy rotation.
   - Add support for key usage quotas.
   - Enhance logging and audit capabilities.

---

### Authors

This module was created following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to further enhance its functionality.

---

### Useful Resources

- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/index.html)
- [Best Practices for AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [Symmetric and Asymmetric KMS Keys](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#symmetric-asymmetric)
- [AWS Config Rules for KMS](https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_kms.html)
- [AWS IAM Policies for KMS](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)
- [AWS CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/index.html)
- [AWS Config Documentation](https://docs.aws.amazon.com/config/index.html)
- [AWS KMS Key Rotation Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)
- [AWS Multi-Region Keys Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html)
- [AWS Encryption SDK](https://docs.aws.amazon.com/encryption-sdk/latest/developer-guide/what-is.html)
- [AWS KMS Metrics Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/monitoring-cloudwatch.html)
- [AWS Backup Documentation](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html)