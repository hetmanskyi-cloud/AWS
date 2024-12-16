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
  source               = "./modules/kms"
  aws_account_id       = "123456789012"
  aws_region           = "eu-west-1"
  name_prefix          = "dev"
  environment          = "dev"
  additional_principals = [
    "arn:aws:iam::123456789012:role/example-role",
    "arn:aws:iam::123456789012:role/another-role"
  ]
}

output "kms_key_arn" {
  value = module.kms.kms_key_arn
}

---

## Security Best Practices

1. **Key Rotation**:
   - Enable automatic key rotation to reduce the risk of compromised encryption keys.

2. **Access Policies**:
   - Grant only the necessary permissions to additional principals using `additional_principals`.
   - Regularly review and update the key policy to ensure it aligns with security requirements.

3. **Environment Isolation**:
   - Use distinct KMS keys for each environment (e.g., dev, stage, prod) to maintain resource isolation.

4. **Monitoring**:
   - Monitor key usage through AWS CloudTrail to detect unauthorized access or anomalies.

---

### Notes

- This KMS key is designed for general encryption purposes and can be extended to meet specific needs.
- Ensure proper tagging to differentiate resources across environments.

---

### Future Improvements

1. **Add support for alias creation to simplify key management**:
   - Creating aliases for KMS keys provides a user-friendly way to reference the keys.
   - Instead of using full ARNs, services or developers can use the alias name (e.g., `alias/project-key`) to interact with the key.
   - This can also help in scenarios where keys need to be rotated or replaced without changing the configurations in dependent services.

2. **Include predefined IAM roles for common use cases (e.g., Lambda, ECS)**:
   - Predefining IAM roles for specific services (e.g., Lambda functions or ECS tasks) simplifies access control setup.
   - These roles can include scoped-down policies that only allow access to perform necessary actions like encrypting and decrypting data with the KMS key.
   - This approach improves security by adhering to the principle of least privilege.

3. **Integrate key usage monitoring alerts using CloudWatch Alarms**:
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