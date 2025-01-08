# VPC Endpoints Module for Terraform

This module creates and manages VPC Interface Endpoints for AWS Systems Manager (SSM), SSM Messages, and EC2 Messages within a specified VPC. It also configures optional CloudWatch Logs for monitoring VPC Endpoint traffic and sets up the necessary Security Groups to control access. Gateway Endpoints for S3 and DynamoDB creates in `vpc module`.

---

### Prerequisites

- **AWS Provider Configuration**:
  Ensure that the `aws` provider is configured with the appropriate region and credentials in the root module's `providers.tf` file.

- **Existing VPC and Subnets**:
  The module requires an existing VPC and a set of private subnets where the Interface Endpoints will be deployed.

---

## Features

- **Creates VPC Interface Endpoints**:
  - **SSM Endpoint**: Provides access to AWS Systems Manager for instances in private subnets.
  - **SSM Messages Endpoint**: Facilitates communication for the Systems Manager Agent.
  - **EC2 Messages Endpoint**: Enables Systems Manager operations for EC2 instances.

- **Optional CloudWatch Logs Integration**:
  - Creates a CloudWatch Log Group for monitoring VPC Endpoint traffic.
  - Enables detailed logging for traffic analysis and troubleshooting when `enable_cloudwatch_logs_for_endpoints` is set to `true`.

- **Security Group Configuration**:
  - Creates a dedicated Security Group for VPC Endpoints.
  - Ingress rules allow HTTPS access (port 443) from specified private subnets.
  - Egress rules permit unrestricted outbound traffic for seamless communication with AWS services.

- **Environment-Specific Tags**:
  - Tags include the resource name and environment (e.g., dev, stage, prod) for better organization and tracking.

---

## Files Structure

| **File**               | **Description**                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------|
| `main.tf`              | Creates VPC Interface Endpoints and configures optional CloudWatch Logs policies.                       |
| `cloudwatch_logs.tf`   | Defines the CloudWatch Log Group for monitoring VPC Endpoint traffic.                                   |
| `security_group.tf`    | Configures the Security Group for controlling access to the VPC Endpoints.                              |
| `variables.tf`         | Declares input variables for the module.                                                                |
| `outputs.tf`           | Exposes key outputs for integration with other modules or resources.                                    |

---

## Input Variables

| **Name**                              | **Type**       | **Description**                              | **Default/Required**                                          |
|---------------------------------------|----------------|----------------------------------------------|---------------------------------------------------------------|
| `aws_region`                          | `string`       | AWS region for resource creation.            | **Required**                                                  |
| `aws_account_id`                      | `string`       | AWS account ID for permissions/policies.     | **Required**                                                  |
| `name_prefix`                         | `string`       | Prefix for resource names.                   | **Required**                                                  |
| `environment`                         | `string`       | Environment label (dev, stage, prod).        | **Required**                                                  |
| `vpc_id`                              | `string`       | VPC ID for endpoint creation.                | **Required**                                                  |
| `private_subnet_ids`                  | `list(string)` | Private subnet IDs for Interface Endpoints.  | **Required**                                                  |
| `private_subnet_cidr_blocks`          | `list(string)` | CIDRs for subnets, must match subnet IDs.    | **Required**                                                  |
| `kms_key_arn`                         | `string`       | KMS key ARN for log encryption.              | **Required** if `enable_cloudwatch_logs_for_endpoints` = true |
| `enable_cloudwatch_logs_for_endpoints`| `bool`         | Enable CloudWatch Logs for VPC Endpoints.    | `false` (Optional)                                            |
| `endpoints_log_retention_in_days`     | `number`       | Retention period for logs (days).            | `14` (Optional)                                               |

**Note:**
- `kms_key_arn` is only required when `enable_cloudwatch_logs_for_endpoints` is set to `true`.
- Make sure this KMS key is provided by the KMS module if logging is enabled.

---

## Outputs

| **Name**                    | **Description**                                           |
|-----------------------------|-----------------------------------------------------------|
| `ssm_endpoint_id`           | The ID of the SSM Interface Endpoint.                     |
| `ssm_messages_endpoint_id`  | The ID of the SSM Messages Interface Endpoint.            |
| `ec2_messages_endpoint_id`  | The ID of the EC2 Messages Interface Endpoint.            |
| `endpoint_security_group_id`| ID of the Security Group for VPC Endpoints.               |
| `ssm_endpoint_dns_names`    | DNS names for the SSM Interface Endpoint.                 |

---

## Usage Example

```hcl
module "vpc_endpoints" {
  source                     = "./modules/endpoints"
  
  aws_region                 = var.aws_region
  aws_account_id             = var.aws_account_id
  environment                = var.environment
  name_prefix                = var.name_prefix
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  kms_key_arn                = module.kms.kms_key_arn # Reference to KMS module's output

  enable_cloudwatch_logs_for_endpoints = true
  endpoints_log_retention_in_days      = 14
}

output "vpc_endpoints_ssm_id" {
  value = module.vpc_endpoints.ssm_endpoint_id
}

output "vpc_endpoints_security_group_id" {
  value = module.vpc_endpoints.endpoint_security_group_id
}

---

### Initial Setup

During the initial setup of VPC Endpoints, it's essential to configure logging and security appropriately to ensure secure and efficient operation.

**Step 1: Create the Endpoints with Logging (Optional)**

- Set `enable_cloudwatch_logs_for_endpoints = true` to enable CloudWatch Logs for monitoring.
- Provide a valid `kms_key_arn` to encrypt the logs.
- This setup provides visibility into traffic and aids in troubleshooting.

**Step 2: Review and Adjust Security Policies**

- Ensure that the Security Group rules align with your organization's security policies.
- Modify ingress or egress rules as necessary to meet specific requirements.

**Step 3: Integrate with Other Modules**

- Reference the outputs in other modules or resources to ensure seamless integration and communication.

**Step 4: Monitor and Maintain**

- Regularly review CloudWatch Logs (if enabled) to monitor endpoint traffic.
- Adjust log retention periods and security group rules based on evolving needs.

This step-by-step process ensures the secure and efficient management of VPC Endpoints while adhering to best practices.

---

## Security Best Practices

**Key Rotation:**

- Enable automatic key rotation to reduce the risk of compromised encryption keys.

**Access Policies:**

- **During Initial Setup:**
  - Full access is granted to the AWS root account for ease of configuration.
  
- **After Setup:**
  - Review and update the key policy to:
    - Remove root access.
    - Grant only necessary permissions to IAM roles and services.
  - Use the `additional_principals` variable to define additional entities requiring access.

**Environment Isolation:**

- Use separate KMS keys for each environment (e.g., dev, stage, prod) to maintain resource isolation.

**Monitoring:**

- Monitor key usage through AWS CloudWatch Alarms to detect unauthorized access or anomalies.

**IAM Role Management:**

- If `enable_kms_role` is enabled, ensure the IAM role has only necessary permissions to manage the KMS key.
- Regularly review and audit IAM roles and policies associated with the KMS key.

---

## Future Improvements

**Deploy Policy Setup:**

- Provide more detailed control in the `additional_principals` variable to allow specific actions (e.g., `kms:EncryptOnly` or `kms:DecryptOnly`) for certain principals.

**Enhance Monitoring and Notifications:**

- Introduce additional metrics or thresholds to monitor key usage, such as tracking encryption errors or unusual usage patterns.

**Environment-Related Enhancements:**

- Implement stricter key policies for production environments, ensuring tighter access control.

**Centralized CloudTrail Integration:**

- Use a separate module (if needed) for CloudTrail to centralize auditing and logging across all AWS services, including KMS.

---

### Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

### Useful Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)
- [AWS CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
- [AWS Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Best Practices for AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/best-practices.html)

---