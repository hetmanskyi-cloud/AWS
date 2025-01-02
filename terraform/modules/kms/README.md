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
- **Environment-Specific Tags**:
  - Tags include the resource name and environment (e.g., dev, stage, prod) for better organization and tracking.

---

## Files Structure

| **File**         | **Description**                                                                      |
|------------------|--------------------------------------------------------------------------------------|
| `main.tf`        | Creates the KMS key, defines policies, and configures access for services and roles. |
| `variables.tf`   | Declares input variables for the module.                                             |
| `outputs.tf`     | Exposes key outputs for integration with other modules.                              |

---

## Input Variables

| **Name**               | **Type**       | **Description**                                                                                 | **Default/Required**  |
|------------------------|----------------|-------------------------------------------------------------------------------------------------|-----------------------|
| `aws_account_id`       | `string`       | AWS Account ID for configuring permissions in the KMS key policy.                               | Required              |
| `aws_region`           | `string`       | AWS Region where the resources are created.                                                     | Required              |
| `name_prefix`          | `string`       | Name prefix for all resources.                                                                  | Required              |
| `environment`          | `string`       | Environment for the resources (e.g., dev, stage, prod).                                         | Required              |
| `additional_principals`| `list(string)` | List of additional AWS principals (e.g., services or IAM roles) requiring access to the KMS key.| `[]` (Optional)       |

---

## Outputs

| **Name**      | **Description**                                           |
|---------------|-----------------------------------------------------------|
| `kms_key_arn` | ARN of the KMS encryption key for other resources to use. |

---

## Usage Example

```hcl
module "kms" {
  source                     = "./modules/kms"
  aws_account_id             = "123456789012"
  aws_region                 = "eu-west-1"
  name_prefix                = "dev"
  environment                = "dev"
  enable_kms_management_role = false # Activate after initial setup KMS
  additional_principals = [
    "arn:aws:iam::123456789012:role/example-role",
    "arn:aws:iam::123456789012:role/another-role"
  ]
}

output "kms_key_arn" {
  value = module.kms.kms_key_arn
}
```

---

### Initial Setup

During the initial creation of the KMS key, full access is granted to the AWS account root principal to simplify setup and ensure that the key can be managed securely. However, **it is strongly recommended to update the KMS key policy after initial creation** to restrict access and adhere to the principle of least privilege.  

1. **Step 1**: Create the key with root access using the default settings in this module.
2. **Step 2**: Review and update the KMS key policy to remove root access and grant specific permissions to IAM roles or services that require access.
3. **Step 3**: Test the updated policy to ensure it meets the operational requirements without introducing unnecessary risks.

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

1. **Add support for alias creation**:  
   - Creating aliases for KMS keys provides a user-friendly way to reference the keys.
   - Instead of using full ARNs, services or developers can use the alias name (e.g., `alias/project-key`) to interact with the key.
   - This simplifies key management and allows for easier key rotation.

2. **Integrate key usage monitoring alerts using CloudWatch Alarms**:  
   - Setting up CloudWatch Alarms to monitor KMS key usage can help detect potential security issues or anomalies.  
   - Example metrics to monitor include:  
     - Number of encryption and decryption requests.  
     - Unauthorized access attempts.  
   - Notifications can be sent to an SNS topic, enabling real-time alerting and faster response to suspicious activities.

---

### Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

### Useful Resources

- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/index.html)
- [Best Practices for AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS IAM Policies for KMS](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)

---