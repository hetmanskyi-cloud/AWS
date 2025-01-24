# VPC Module for Terraform

This module creates and manages a Virtual Private Cloud (VPC) in AWS, including public and private subnets, route tables, Internet Gateway, Network ACLs (NACLs), and VPC Flow Logs. It provides a secure, scalable, and configurable networking foundation for AWS infrastructure.

---

## **Features**

- **VPC Creation**:
  - Creates a VPC with a configurable CIDR block and DNS support.
- **Subnet Management**:
  - Configures public and private subnets across multiple availability zones.
  - Automatically assigns public IPs to instances launched in public subnets.
- **Route Tables**:
  - Creates route tables for public and private subnets:
    - Public route table for internet access via an Internet Gateway.
    - Private route table for secure access to S3 and DynamoDB via Gateway Endpoints.
- **Network ACLs (NACLs)**:
  - Configurable rules for controlling inbound and outbound traffic:
    - Public NACL: Allows HTTP, HTTPS, and SSH traffic.
    - Private NACL: Allows MySQL, Redis, DNS, and ephemeral traffic within the VPC.
  - NACLs operate at the subnet level, while Security Groups (SG) restrict traffic at the instance level.
- **VPC Flow Logs**:
  - Logs VPC traffic to CloudWatch Logs with encryption using a KMS key.
  - Automatically creates an IAM Role with minimal permissions for CloudWatch logging.
- **Gateway Endpoints**:
  - Configurable S3 and DynamoDB endpoints for private access without requiring a NAT Gateway.
- **Flexible Access Control**:
  - SSH, HTTP, and HTTPS access can be dynamically enabled or disabled using input variables (`enable_ssh_access`, `enable_public_nacl_http`, `enable_public_nacl_https`).
- **Tagging**:
  - Consistent tagging for resource tracking and cost allocation.

---

## **File Structure**

| **File**              | **Description**                                                                 |
|-----------------------|---------------------------------------------------------------------------------|
| `main.tf`             | Defines the VPC, subnets, and main configurations.                              |
| `gateway_routes.tf`   | Configures route tables, Internet Gateway, and Gateway Endpoints.               |
| `nacl.tf`             | Creates and associates Network ACLs for public and private subnets.             |
| `flow_logs.tf`        | Configures VPC Flow Logs and related IAM roles and policies.                    |
| `variables.tf`        | Declares input variables for the module.                                        |
| `outputs.tf`          | Exposes key outputs for integration with other modules.                         |

---

## **Input Variables**

| **Name**                         | **Type**       | **Description**                                                          | **Default/Required**       |
|----------------------------------|----------------|--------------------------------------------------------------------------|----------------------------|
| `aws_region`                     | `string`       | AWS region where resources will be created.                              | **Required**               |
| `aws_account_id`                 | `string`       | AWS account ID for configuring permissions.                              | **Required**               |
| `vpc_cidr_block`                 | `string`       | CIDR block for the VPC.                                                  | **Required**               |
| `name_prefix`                    | `string`       | Prefix for resource names.                                               | **Required**               |
| `environment`                    | `string`       | Environment tag (e.g., dev, stage, prod).                                | **Required**               |
| `public_subnet_cidr_block_1`     | `string`       | CIDR block for the first public subnet.                                  | **Required**               |
| `public_subnet_cidr_block_2`     | `string`       | CIDR block for the second public subnet.                                 | **Required**               |
| `public_subnet_cidr_block_3`     | `string`       | CIDR block for the third public subnet.                                  | **Required**               |
| `private_subnet_cidr_block_1`    | `string`       | CIDR block for the first private subnet.                                 | **Required**               |
| `private_subnet_cidr_block_2`    | `string`       | CIDR block for the second private subnet.                                | **Required**               |
| `private_subnet_cidr_block_3`    | `string`       | CIDR block for the third private subnet.                                 | **Required**               |
| `kms_key_arn`                    | `string`       | ARN of the KMS key for encrypting CloudWatch Logs.                       | **Required**               |
| `flow_logs_retention_in_days`    | `number`       | Retention period for VPC Flow Logs in CloudWatch.                        | `7` (Default)              |
| `enable_ssh_access`              | `bool`         | Enable or disable SSH access (public NACL rule).                         | `false` (Optional)         |
| `enable_public_nacl_http`        | `bool`         | Enable or disable HTTP access (public NACL rule).                        | `false` (Optional)         |
| `enable_public_nacl_https`       | `bool`         | Enable or disable HTTPS access (public NACL rule).                       | `false` (Optional)         |

---

## **Outputs**

| **Name**                         | **Description**                                                      |
|----------------------------------|----------------------------------------------------------------------|
| `vpc_id`                         | The ID of the created VPC.                                           |
| `public_subnets`                 | List of public subnet IDs.                                           |
| `private_subnets`                | List of private subnet IDs.                                          |
| `public_route_table_id`          | ID of the public route table.                                        |
| `private_route_table_id`         | ID of the private route table.                                       |
| `vpc_flow_logs_log_group_name`   | Name of the CloudWatch Log Group for VPC Flow Logs.                  |
| `vpc_flow_logs_role_arn`         | ARN of the IAM Role for VPC Flow Logs.                               |
| `s3_endpoint_id`                 | ID of the S3 Gateway Endpoint.                                       |
| `dynamodb_endpoint_id`           | ID of the DynamoDB Gateway Endpoint.                                 |
| `default_security_group_id`      | The ID of the default security group for the VPC.                    |

---

## **Usage Example**

```hcl
module "vpc" {
  source                        = "./modules/vpc"
  aws_region                    = "eu-west-1"
  aws_account_id                = "123456789012"
  vpc_cidr_block                = "10.0.0.0/16"
  name_prefix                   = "dev"
  environment                   = "dev"
  public_subnet_cidr_block_1    = "10.0.1.0/24"
  public_subnet_cidr_block_2    = "10.0.2.0/24"
  public_subnet_cidr_block_3    = "10.0.3.0/24"
  private_subnet_cidr_block_1   = "10.0.4.0/24"
  private_subnet_cidr_block_2   = "10.0.5.0/24"
  private_subnet_cidr_block_3   = "10.0.6.0/24"
  kms_key_arn                   = "arn:aws:kms:eu-west-1:123456789012:key/example"
  flow_logs_retention_in_days   = 7
  enable_ssh_access             = true
  enable_public_nacl_http       = true
  enable_public_nacl_https      = true
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

---

## **Notes**

1. **Flow Logs**:
   - Configured to log all traffic (accepted, rejected, and all) to CloudWatch Logs.
   - KMS encryption ensures secure log storage.
   - Automatically creates an IAM role with minimal permissions for CloudWatch.
2. **Gateway Endpoints**:
   - S3 and DynamoDB Gateway Endpoints allow private access without requiring a NAT Gateway.
3. **Security**:
   - Public subnets support direct internet access, controlled by NACL and route table configurations.
   - SSH, HTTP, and HTTPS access can be dynamically enabled or disabled via input variables.

---

## **Future Improvements**

1. **Implement Data Validation for Input Variables**:
  - Introduce validations for input variables, such as CIDR blocks, to ensure correctness and prevent configuration errors.
Example:
  - Validate that all CIDR blocks are in proper format (e.g., 10.0.0.0/16).
  - Check that subnet CIDR blocks are subsets of the VPC CIDR block.
Benefit:
  - Simplifies debugging by providing clear error messages for invalid inputs.
  - Reduces the risk of misconfigurations affecting infrastructure deployment.

---

## Authors

This module was developed following Terraform best practices, ensuring flexibility, scalability, and security. Contributions and feedback are highly appreciated!

---

## Useful Resources

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [Terraform VPC Module Guide](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS Network ACLs Overview](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

---