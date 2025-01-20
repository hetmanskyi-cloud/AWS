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
  - Designed for encrypting CloudWatch Logs, S3 buckets, and other AWS resources.
  - Includes a flexible policy that grants permissions to the root account, AWS services, and additional principals.
  - Supports automatic key rotation for enhanced security.

- **Customizable Access Policies**:
  - Base permissions provide full access to the root account and encryption services like CloudWatch Logs, ElastiCache, ALB Access Logs, and S3.
  - Additional permissions can be dynamically configured for other AWS principals (e.g., IAM roles, services) via the `additional_principals` variable.

- **Optional IAM Role for Key Management**:
  - Conditional creation of an IAM role and associated policy for administrative management of the KMS key.
  - Enables granular control over key management permissions, replacing root-level access for better security and compliance.

- **CloudWatch Monitoring**:
  - Create CloudWatch Alarms to monitor KMS key usage (e.g., decrypt operations).
  - Fully configurable thresholds and notification settings via variables.
  - Conditional creation based on the `enable_key_monitoring` variable.

- **Environment-Specific Tags**:
  - Tags include the resource name and environment (e.g., dev, stage, prod) for better organization and tracking.

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

| **Name**                | **Type**       | **Description**                                                        | **Default/Required**  |
|-------------------------|----------------|------------------------------------------------------------------------|-----------------------|
| `aws_account_id`        | `string`       | AWS Account ID for configuring permissions in the KMS key policy.      | **Required**          |
| `aws_region`            | `string`       | AWS Region where the resources are created.                            | **Required**          |
| `name_prefix`           | `string`       | Name prefix for all resources.                                         | **Required**          |
| `environment`           | `string`       | Environment for the resources (e.g., dev, stage, prod).                | **Required**          |
| `additional_principals` | `list(string)` | Additional AWS principals to grant access to the KMS key.              | `[]` (Optional)       |
| `enable_kms_role`       | `bool`         | Enable or disable the creation of an IAM role for KMS management.      | `false` (Optional)    |
| `enable_key_monitoring` | `bool`         | Enable or disable CloudWatch Alarms for monitoring KMS key usage.      | `false` (Optional)    |
| `key_decrypt_threshold` | `number`       | Threshold for KMS decrypt operations to trigger an alarm.              | `100` (Optional)      |
| `sns_topic_arn`         | `string`       | ARN of the SNS Topic for sending CloudWatch alarm notifications.       | **Required**          |

---

## Outputs

| **Name**                    | **Description**                                           |
|-----------------------------|-----------------------------------------------------------|
| `kms_key_arn`               | ARN of the KMS encryption key for other resources to use. |
| `enable_kms_role`           | Indicates if the IAM role for KMS management was created. |
| `kms_management_role_arn`   | ARN of the IAM role for managing the KMS encryption key.  |
| `kms_management_policy_arn` | ARN of the KMS management policy for managing the key.    |
| `kms_decrypt_alarm_arn`     | The ARN of the CloudWatch Alarm for decrypt operations.   |

---

## Usage Example

```hcl
module "kms" {
  source                = "./modules/kms" # Path to module KMS

  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  environment           = var.environment
  name_prefix           = var.name_prefix
  additional_principals = var.additional_principals           # List of additional principals
  enable_key_rotation   = var.enable_key_rotation             # Enable automatic key rotation
  enable_kms_role       = var.enable_kms_role                 # Activate after initial setup KMS
  enable_key_monitoring = var.enable_key_monitoring           # Enable CloudWatch Alarms for KMS monitoring
  key_decrypt_threshold = var.key_decrypt_threshold           # Set a custom threshold for Decrypt operations, adjust as needed
  sns_topic_arn         = aws_sns_topic.cloudwatch_alarms.arn # SNS Topic for CloudWatch Alarms

  depends_on = [aws_sns_topic.cloudwatch_alarms] # Ensure SNS topic is created before KMS module
}

output "kms_key_arn" {
  value = module.kms.kms_key_arn
}
```

---

### Initial Setup

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
3. **Step 3**: Grant specific permissions to IAM roles or services that require access using the `additional_principals` variable.
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
       - Remove root access.
       - Grant only necessary permissions to IAM roles and services.
     - Use the `additional_principals` variable to define additional entities requiring access.

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
   Provide more detailed control in the `additional_principals` variable to allow specific actions (e.g., `kms:EncryptOnly` or `kms:DecryptOnly`) for certain principals.

2. **Enhance Monitoring and Notifications**:
   Introduce additional metrics or thresholds to monitor key usage, such as tracking encryption errors or unusual usage patterns.

3. **Environment-Related Enhancements**:
   Implement stricter key policies for production environments, ensuring tighter access control.

4. **Centralized CloudTrail Integration**:
   Use a separate module (if needed) for CloudTrail to centralize auditing and logging across all AWS services, including KMS.

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

---