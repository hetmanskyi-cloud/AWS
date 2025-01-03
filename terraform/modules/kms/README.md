# KMS Module for Terraform

This module creates and manages a KMS (Key Management Service) key in AWS. The key is designed for general encryption purposes, such as securing CloudWatch Logs, S3 buckets, and other resources. It supports automatic key rotation and dynamic configuration of permissions.

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
  - Base permissions provide full access to the root account and encryption services like CloudWatch Logs.
  - Additional permissions can be dynamically configured for other AWS principals (e.g., IAM roles, services).

- **CloudWatch Monitoring**:
  - Create CloudWatch Alarms to monitor KMS key usage (e.g., decrypt operations).
  - Fully configurable thresholds and notification settings via variables.

- **Alias Support**:
  - Conditional creation of a user-friendly alias for the KMS key.

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

| **Name**                  | **Type**       | **Description**                                                       | **Default/Required**  |
|---------------------------|----------------|------------------------------------------------------------------------|-----------------------|
| `aws_account_id`          | `string`       | AWS Account ID for configuring permissions in the KMS key policy.      | Required              |
| `aws_region`              | `string`       | AWS Region where the resources are created.                            | Required              |
| `name_prefix`             | `string`       | Name prefix for all resources.                                         | Required              |
| `environment`             | `string`       | Environment for the resources (e.g., dev, stage, prod).                | Required              |
| `additional_principals`   | `list(string)` | Additional AWS principals to grant access to the KMS key.              | `[]` (Optional)       |
| `enable_kms_role`         | `bool`         | Enable or disable the creation of an IAM role for KMS management.      | `false`               |
| `enable_key_monitoring`   | `bool`         | Enable or disable CloudWatch Alarms for monitoring KMS key usage.      | `false`               |
| `key_decrypt_threshold`   | `number`       | Threshold for KMS decrypt operations to trigger an alarm.              | `100`                 |
| `enable_kms_alias`        | `bool`         | Enable or disable the creation of a KMS alias.                         | `false`               |
| `sns_topic_arn`           | `string`       | ARN of the SNS Topic for sending CloudWatch alarm notifications.       | Required              |

---

## Outputs

| **Name**                      | **Description**                                           |
|-------------------------------|-----------------------------------------------------------|
| `kms_key_arn`                 | ARN of the KMS encryption key for other resources to use. |
| `kms_management_role_arn`     | ARN of the IAM role for managing the KMS encryption key.  |
| `kms_management_policy_arn`   | ARN of the KMS management policy for managing the key.    |
| `kms_key_alias`               | The name of the KMS key alias.                            |
| `kms_decrypt_alarm_arn`       | The ARN of the CloudWatch Alarm for decrypt operations.   |

---

## Usage Example

```hcl
module "kms" {
  source                     = "./modules/kms"
  aws_account_id             = "123456789012"
  aws_region                 = "eu-west-1"
  name_prefix                = "dev"
  environment                = "dev"
  enable_kms_role            = false # Activate after initial setup KMS
  additional_principals = [
    "arn:aws:iam::123456789012:role/example-role",
    "arn:aws:iam::123456789012:role/another-role"
  ]
  enable_key_monitoring      = true
  key_decrypt_threshold      = 100
  sns_topic_arn              = "arn:aws:sns:eu-west-1:123456789012:example-topic"
}

output "kms_key_arn" {
  value = module.kms.kms_key_arn
}
```

---

### Initial Setup

During the initial creation of the KMS key, full access is granted to the AWS account root principal to simplify setup and ensure that the key can be managed securely. However, **it is strongly recommended to update the KMS key policy after initial creation** to restrict access and adhere to the principle of least privilege.

1. **Step 1**: Create the key with root access using the default settings in this module.  
   - The key policy initially includes root access for simplicity and flexibility during setup.
2. **Step 2**: Review the KMS key policy in the Terraform code and remove root access:
   - Delete the policy statement that grants root access (`"Principal": { "AWS": "arn:aws:iam::<aws_account_id>:root" }`).
   - Example:
     ```hcl
     {
       Effect    = "Allow",
       Principal = { AWS = "arn:aws:iam::123456789012:root" },
       Action    = "kms:*",
       Resource  = "<kms_key_arn>"
     }
     ```
   - Update the Terraform configuration with the revised policy and apply the changes (`terraform apply`).
3. **Step 3**: Grant specific permissions to IAM roles or services that require access using the `additional_principals` variable.
4. **Step 4**: Test the updated policy to ensure it meets operational requirements without introducing unnecessary risks.

This step-by-step process ensures the secure management of the KMS key while following the **principle of least privilege**.

---

## Security Best Practices

1. **Key Rotation**:  
   Enable automatic key rotation to reduce the risk of compromised encryption keys.

2. **Access Policies**:  
   - During initial setup, full access is granted to the AWS root account for ease of configuration.  
   - After setup, review and update the key policy to:  
     - Remove root access.  
     - Grant only necessary permissions to IAM roles and services.  
   - Use the `additional_principals` variable to define additional entities requiring access.

3. **Environment Isolation**:  
   Use distinct KMS keys for each environment (e.g., dev, stage, prod) to maintain resource isolation.

4. **Monitoring**:  
   Monitor key usage through AWS CloudTrail to detect unauthorized access or anomalies.

---

## Future Improvements

1. **Expand Policy Customization**:  
   - Provide more granular controls in the `additional_principals` variable to allow specific actions (e.g., `kms:EncryptOnly` or `kms:DecryptOnly`) for certain principals.

2. **Enhance Monitoring and Notifications**:  
   - Introduce additional metrics or thresholds to monitor key usage, such as tracking encryption errors or unusual patterns of usage.

3. **Environment-Specific Enhancements**:  
   - Implement stricter key policies for production environments, ensuring tighter control over access.

---

### Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

### Useful Resources

- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/index.html)
- [Best Practices for AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS IAM Policies for KMS](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)

---