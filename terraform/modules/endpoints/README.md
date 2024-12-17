# Endpoints Module for Terraform

This module creates and manages VPC Endpoints (Gateway and Interface) in AWS to enable private access to AWS services, such as S3 and Systems Manager (SSM), from within a VPC. It supports secure communication, optional CloudWatch Logs for monitoring, and controlled access through Security Groups.

---

### Prerequisites

- **AWS Provider Configuration**:
The region and other parameters of the `aws` provider are specified in the `providers.tf` file of the root block.

An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Creates Gateway and Interface VPC Endpoints**:
  - Gateway Endpoint for **S3**: Enables private access to S3 without the need for an internet gateway.
  - Interface Endpoints for **SSM**, **SSM Messages**, and **EC2 Messages**: Provide secure access to Systems Manager services from private subnets.
- **Security Group Configuration**:
  - A Security Group is created to restrict access to Interface Endpoints over HTTPS (port 443) from private subnet CIDR blocks.
- **Optional CloudWatch Logs Integration**:
  - CloudWatch Logs can be enabled in **stage** and **prod** environments for traffic monitoring and troubleshooting.
- **Tagging**:
  - Consistent tags are applied to all resources for better management and identification.

---

## Files Structure

| **File**               | **Description**                                                                |
|------------------------|--------------------------------------------------------------------------------|
| `main.tf`              | Creates VPC Endpoints (Gateway for S3 and Interface for SSM-related services). |
| `security_group.tf`    | Defines the Security Group for Interface VPC Endpoints.                        |
| `cloudwatch_logs.tf`   | Configures CloudWatch Log Groups for monitoring VPC Endpoint traffic.          |
| `variables.tf`         | Declares input variables for the module.                                       |
| `outputs.tf`           | Exposes key outputs for integration with other modules.                        |

---

## Input Variables

| **Name**                               | **Type**       | **Description**                                                                     | **Default/Required**  |
|----------------------------------------|----------------|-------------------------------------------------------------------------------------|-----------------------|
| `aws_region`                           | `string`       | AWS region where resources will be created.                                         | Required              |
| `name_prefix`                          | `string`       | Prefix for resource names.                                                          | Required              |
| `environment`                          | `string`       | Environment for the resources (e.g., dev, stage, prod).                             | Required              |
| `vpc_id`                               | `string`       | The VPC ID where endpoints will be created.                                         | Required              |
| `private_subnet_ids`                   | `list(string)` | List of private subnet IDs for Interface Endpoints.                                 | Required              |
| `private_subnet_cidr_blocks`           | `list(string)` | CIDR blocks for private subnets (used for Security Group ingress rules).            | Required              |
| `route_table_ids`                      | `list(string)` | List of route table IDs for the S3 Gateway Endpoint.                                | Required              |
| `endpoint_sg_id`                       | `string`       | Security Group ID for Interface Endpoints. Created by this module.                  | Required              |
| `enable_cloudwatch_logs_for_endpoints` | `bool`         | Enable CloudWatch Logs for VPC Endpoints in stage and prod environments.            | `false`               |

---

## Outputs

| **Name**                        | **Description**                                       |
|---------------------------------|-------------------------------------------------------|
| `s3_endpoint_id`                | The ID of the S3 Gateway Endpoint.                    |
| `ssm_endpoint_id`               | The ID of the SSM Interface Endpoint.                 |
| `ssm_messages_endpoint_id`      | The ID of the SSM Messages Interface Endpoint.        |
| `ec2_messages_endpoint_id`      | The ID of the EC2 Messages Interface Endpoint.        |
| `endpoint_security_group_id`    | ID of the Security Group for Interface VPC Endpoints. |

---

## Usage Example

```hcl
module "endpoints" {
  source                               = "./modules/endpoints"
  aws_region                           = "eu-west-1"
  name_prefix                          = "prod"
  environment                          = "prod"
  vpc_id                               = "vpc-0123456789abcdef0"
  private_subnet_ids                   = ["subnet-abcdef1234567890", "subnet-012345abcdef6789"]
  private_subnet_cidr_blocks           = ["10.0.1.0/24", "10.0.2.0/24"]
  route_table_ids                      = ["rtb-0123456789abcdef0"]
  endpoint_sg_id                       = "sg-0123456789abcdef0"
  enable_cloudwatch_logs_for_endpoints = true
}

output "s3_endpoint_id" {
  value = module.endpoints.s3_endpoint_id
}

---

## Security Best Practices

1. **Restrict Access to Interface Endpoints**:
   - Use Security Groups to allow HTTPS (port 443) access only from private subnet CIDR blocks.
2. **Enable CloudWatch Logs**:
   - Monitor traffic to Interface Endpoints in `stage` and `prod` environments.
3. **Tagging**:
   - Apply consistent tags to all resources for better visibility and management.
4. **No Internet Exposure**:
   - The S3 Gateway Endpoint ensures private access to S3 without requiring public routes.

---

### Notes

- CloudWatch Logs are optional and should only be enabled in `stage` and `prod` environments to reduce costs.
- CloudWatch Logs retention policy is set to 14 days by default and can be modified as needed.
- Security Groups are created specifically for Interface Endpoints and restrict access to private networks.
- Tags ensure all resources are easily identifiable across environments.

---

### Future Improvements

1. Add support for additional AWS services requiring VPC Endpoints.
2. Include customizable retention policies for CloudWatch Logs.
3. Enable monitoring and alerts for Endpoint traffic using CloudWatch Alarms.

---

### Authors

This module was crafted following Terraform best practices, emphasizing security, scalability, and maintainability. Contributions and feedback are welcome to enhance its functionality further.

---

### Useful Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)

---