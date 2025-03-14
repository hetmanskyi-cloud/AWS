# AWS Interface Endpoints Terraform Module

Terraform module to provision AWS Interface VPC Endpoints for secure and private communication with essential AWS services within your VPC.

## Overview

This module creates Interface VPC Endpoints for secure and highly available access to AWS services without traversing the public internet, enhancing security and reliability.
Using this module allows you to configure access to EC2 instances through AWS Systems Manager Session Manager, which allows you to completely disable SSH access if necessary, increasing the level of infrastructure security.

### Supported AWS Services:
- **AWS Systems Manager (SSM)**
- **SSM Messages**
- **EC2 Messages (for Auto Scaling Group communication)**
- **CloudWatch Logs**
- **AWS Key Management Service (KMS)**

Endpoints are deployed across all private subnets, ensuring high availability across multiple Availability Zones (AZ).

## Requirements

| Name         | Version   |
|--------------|-----------|
| Terraform    | >= 1.11   |
| AWS Provider | >= 5.9    |

## Module Architecture

This module provisions:
- **Interface VPC Endpoints** for listed AWS services.
- **Dedicated Security Group** to control HTTPS (port 443) access within the VPC.
- **Inbound and outbound Security Group rules** tailored for secure communication.

## Module File Structure

| File                   | Description                                                      |
|------------------------|------------------------------------------------------------------|
| `main.tf`              | Defines Interface VPC Endpoints configuration for AWS services.  |
| `security_group.tf`    | Security Group rules allowing HTTPS access to the endpoints.     |
| `variables.tf`         | Input variables with detailed validation rules.                  |
| `outputs.tf`           | Module outputs: Endpoint IDs and Security Group ID.              |

## Requirements

- **Existing VPC and Private Subnets**:
  - Ensure the VPC and private subnets exist before deploying this module.

## Inputs

| Name                          | Type           | Description                        | Validation                              |
|-------------------------------|----------------|------------------------------------|-----------------------------------------|
| `aws_region`                  | `string`       | AWS region for resources.          | Format: `xx-xxxx-x` (e.g., `eu-west-1`) |
| `name_prefix`                 | `string`       | Prefix for naming resources.       | Non-empty string                        |
| `environment`                 | `string`       | Deployment environment label.      | One of: `dev`, `stage`, `prod`          |
| `vpc_id`                      | `string`       | ID of the existing VPC.            | Valid AWS VPC ID                        |
| `vpc_cidr_block`              | `string`       | CIDR block of the VPC.             | Valid CIDR block format                 |
| `private_subnet_ids`          | `list(string)` | List of private subnet IDs.        | Valid AWS subnet IDs                    |
| `private_subnet_cidr_blocks`  | `list(string)` | List of private subnet CIDR blocks.| Valid CIDR block format                 |

## Outputs

| **Name**                     | **Description**                                   |
|------------------------------|---------------------------------------------------|
| `ssm_endpoint_id`            | ID of the Systems Manager Interface Endpoint      |
| `ssm_messages_endpoint_id`   | ID of the SSM Messages Interface Endpoint         |
| `asg_messages_endpoint_id`   | ID of the EC2 Messages Interface Endpoint         |
| `cloudwatch_logs_endpoint_id`| ID of the CloudWatch Logs Interface Endpoint      |
| `kms_endpoint_id`            | ID of the KMS Interface Endpoint                  |
| `endpoint_security_group_id` | ID of the Security Group created for endpoints    |

## Example Usage

```hcl
module "interface_endpoints" {
  source = "./modules/interface_endpoints"

  aws_region                  = "eu-west-1"
  name_prefix                 = "dev"
  environment                 = "dev"
  vpc_id                      = module.vpc.vpc_id
  vpc_cidr_block              = module.vpc.vpc_cidr_block
  private_subnet_ids          = module.vpc.private_subnet_ids
  private_subnet_cidr_blocks  = module.vpc.private_subnet_cidr_blocks
}
```

## Security
- **Communication restricted to HTTPS (port 443)**
- **Ingress:** Limited to the VPC CIDR block
- **Egress:** Allowed to AWS services and PrivateLink endpoints (required)
- **Private DNS Enabled:** Allows standard AWS service URLs

## Best Practices
- Deploy Interface Endpoints across all private subnets for high availability.
- Consistently tag all resources for easier management.

## Outputs
Outputs provided:
- Endpoint IDs for each AWS service.
- Security Group ID for managing endpoint access.

## Integration
Integrate seamlessly with other modules:
- **VPC Module**: Provides networking infrastructure (VPC and subnets).
- **ASG Module**: Instances benefit from secure private AWS service access.

---

For additional details and customizations, refer to [AWS VPC Interface Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html).