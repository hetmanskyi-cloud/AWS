# VPC Endpoints Module for Terraform

This module creates and manages VPC Interface Endpoints for AWS Systems Manager (SSM), SSM Messages, and ASG Messages within a specified VPC. It also configures optional CloudWatch Logs for monitoring VPC Endpoint traffic and sets up the necessary Security Groups to control access. Gateway Endpoints for S3 and DynamoDB are created in the `vpc module`.

---

### Prerequisites

- **AWS Provider Configuration**:
  Ensure that the `aws` provider is configured with the appropriate region and credentials in the root module's `providers.tf` file.

- **Existing VPC and Subnets**:
  The module requires an existing VPC and a set of private subnets where the Interface Endpoints will be deployed.

---

## Features

- **Creates VPC Interface Endpoints**:
  - **SSM Endpoint**: Provides access to AWS Systems Manager.
  - **SSM Messages Endpoint**: Facilitates communication for the Systems Manager Agent.
  - **ASG Messages Endpoint**: Enables Systems Manager operations.
  - All endpoints are configured with private DNS enabled for seamless integration.
  - Can be deployed in both private and public subnets based on requirements.

- **Optional CloudWatch Logs Integration**:
  - Creates a CloudWatch Log Group for monitoring VPC Endpoint traffic.
  - Enables detailed logging for traffic analysis and troubleshooting when `enable_cloudwatch_logs_for_endpoints` is set to `true`.

- **Security Group Configuration**:
  - Creates a dedicated Security Group for VPC Endpoints.
  - Ingress rules allow HTTPS access (port 443) from specified private and public subnets.
  - Egress rules permit unrestricted outbound traffic for seamless communication with AWS services (not recommended for production environments).

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
| `public_subnet_ids`                   | `list(string)` | Public subnet IDs for Interface Endpoints.   | `[]` (Optional)                                               |
| `public_subnet_cidr_blocks`           | `list(string)` | CIDRs for public subnets.                    | `[]` (Optional)                                               |
| `kms_key_arn`                         | `string`       | KMS key ARN for log encryption.              | **Required** if `enable_cloudwatch_logs_for_endpoints` = true |
| `enable_cloudwatch_logs_for_endpoints`| `bool`         | Enable CloudWatch Logs for VPC Endpoints.    | `false` (Optional)                                            |
| `endpoints_log_retention_in_days`     | `number`       | Retention period for logs (days).            | `7` (Optional)                                                |

**Note:**
- `kms_key_arn` is required only when `enable_cloudwatch_logs_for_endpoints` is set to `true`.
- Ensure the KMS key has sufficient permissions to create and manage CloudWatch Logs.

---

## Outputs

| **Name**                         | **Description**                                           |
|----------------------------------|-----------------------------------------------------------|
| `ssm_endpoint_id`                | The ID of the SSM Interface Endpoint.                     |
| `ssm_messages_endpoint_id`       | The ID of the SSM Messages Interface Endpoint.            |
| `asg_messages_endpoint_id`       | The ID of the ASG Messages Interface Endpoint.            |
| `endpoint_security_group_id`     | ID of the Security Group for VPC Endpoints.               |
| `endpoints_log_group_arn`        | ARN of the CloudWatch Log Group for VPC Endpoints.        |
| `endpoints_log_group_name`       | Name of the CloudWatch Log Group for VPC Endpoints.       |
| `ssm_endpoint_dns_names`         | DNS names for the SSM Interface Endpoint.                 |
| `ssm_messages_endpoint_dns_names`| DNS names for the SSM Messages Interface Endpoint.        |
| `asg_messages_endpoint_dns_names`| DNS names for the ASG Messages Interface Endpoint.        |
| `endpoints_state`                | State of all VPC endpoints.                               |

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
  public_subnet_ids          = var.public_subnet_ids
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  kms_key_arn                = module.kms.kms_key_arn # Reference to KMS module's output

  enable_cloudwatch_logs_for_endpoints = true
  endpoints_log_retention_in_days      = 7
}

output "vpc_endpoints_ssm_id" {
  value = module.vpc_endpoints.ssm_endpoint_id
}

output "vpc_endpoints_security_group_id" {
  value = module.vpc_endpoints.endpoint_security_group_id
}
```

---

## Security Best Practices

### Egress Rules
- Restrict egress rules to necessary IP addresses and ports to improve security in production environments.
- Avoid using `0.0.0.0/0` in production unless strictly required.

### Testing Environment Note
- Current configuration allows all outbound traffic (`0.0.0.0/0`) for testing purposes.
- This is acceptable for testing but must be reviewed and restricted before production use.

### CloudWatch Logs
- Enable CloudWatch Logs for detailed monitoring and troubleshooting.
- Use a dedicated KMS key for log encryption and ensure key rotation is enabled.

### Access Policies
- Limit permissions for IAM roles and users interacting with this module.
- Review and regularly update security group rules and IAM policies.

---

## Future Improvements

- Add CloudWatch Logs configuration for ASG Messages and SSM Messages endpoints (if needed).
- Introduce granular IAM policies for CloudWatch Logs to limit permissions.
- Implement more restrictive egress rules for production environments.
- Add support for custom endpoint policies.
- Expand the documentation with advanced configurations, such as multi-environment setups and integration with centralized logging solutions.

---

## Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

## Useful Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)
- [AWS CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
- [AWS Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Best Practices for AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/best-practices.html)

---