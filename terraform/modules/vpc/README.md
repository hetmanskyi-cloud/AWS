# VPC Module for Terraform

This module creates and manages a Virtual Private Cloud (VPC) in AWS, including public and private subnets, route tables, Internet Gateway, Network ACLs (NACLs), and VPC Flow Logs. It provides a secure, scalable, and configurable networking foundation for AWS infrastructure.

---

## **Architecture Overview**

```plaintext
                                   Internet Gateway
                                         │
                                         │
                     ┌─────────────┬─────┴─────┬───────────┐
                     │             │           │           │
               Public Subnet  Public Subnet Public Subnet  │
                  (AZ-1)        (AZ-2)       (AZ-3)        │
                     │             │           │           │
                     │             │           │           │
              Private Subnet  Private Subnet Private Subnet│
                  (AZ-1)        (AZ-2)       (AZ-3)        │
                     │             │           │           │
                     └─────────────┼───────────┘           │
                                   │                       │
                         Gateway Endpoints                 │
                         (S3 & DynamoDB)                   │
                                                           │
                                VPC Flow Logs ─────────────┘
                            (CloudWatch Logs)
```

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
  - **Log Configuration**:
    - Captures ALL traffic types (ACCEPT/REJECT)
    - Logs are organized by environment
    - Configurable retention period via `flow_logs_retention_in_days`
  - **Security**:
    - KMS encryption for sensitive log data
    - IAM roles follow principle of least privilege
    - CloudWatch permissions scoped to specific log groups
  - **Resource Management**:
    - Automatic cleanup support in test environments
    - Proper resource tagging for cost allocation
    - Structured log organization by environment
  - **Best Practices**:
    - Regular review of retention periods
    - Cost monitoring recommendations
    - Traffic sampling options for high-traffic environments
- **Gateway Endpoints**:
  - Configurable S3 and DynamoDB endpoints for private access without requiring a NAT Gateway.
- **Flexible Access Control**:
  - SSH, HTTP, and HTTPS access can be dynamically enabled or disabled using input variables (`ssh_allowed_cidr`).
- **Tagging**:
  - Consistent tagging for resource tracking and cost allocation.

---

## **Security**

1. **Network ACLs (NACLs)**:
   - Public subnets:
     - SSH access is configurable with CIDR restrictions
     - Ephemeral ports open for return traffic
   - Private subnets:
     - Allow only necessary ports (MySQL, Redis, DNS)
     - Restricted to VPC CIDR for internal communication
   
2. **Flow Logs Security**:
   - KMS encryption for all log data
   - IAM roles follow principle of least privilege
   - CloudWatch Logs permissions scoped to specific log groups

3. **Security Considerations**:
   - Public IP assignment is restricted to public subnets only
   - Gateway Endpoints provide secure access to AWS services
   - NACL rules are stateless and provide additional security layer

> Note: Some tfsec rules are intentionally ignored with proper documentation (e.g., public IP assignment in public subnets).

## **Cost Management**

1. **VPC Components**:
   - VPC itself - no cost
   - Internet Gateway - no cost
   - Gateway Endpoints - no cost
   - Route Tables - no cost

2. **Flow Logs Costs**:
   - CloudWatch Logs ingestion and storage fees apply
   - Costs vary by region and log volume
   - Example cost calculation:
     ```
     1GB logs/day * 30 days * $0.50/GB = $15/month
     ```

3. **Cost Optimization**:
   - Use log retention policies
   - Consider sampling for high-traffic environments
   - Monitor CloudWatch Logs usage

## **Troubleshooting Guide**

1. **Common Issues**:
   - NACL blocking traffic
   - Flow Logs delivery failures
   - Subnet capacity issues

2. **NACL Debugging**:
   ```shell
   # Check NACL rules
   aws ec2 describe-network-acls --network-acl-id <nacl-id>
   
   # View Flow Logs
   aws logs tail <log-group-name> --follow
   ```

3. **Flow Logs Analysis**:
   - Example log format:
     ```
     <version> <account-id> <interface-id> <srcaddr> <dstaddr> <srcport> <dstport> <protocol> <packets> <bytes> <start> <end> <action> <log-status>
     ```
   - Common fields explanation provided in CloudWatch

## **File Structure**

| **File**              | **Description**                                                                 |
|-----------------------|---------------------------------------------------------------------------------|
| `main.tf`             | Defines the VPC, subnets, and main configurations.                              |
| `endpoints_routes.tf` | Configures route tables, Internet Gateway, and Gateway Endpoints.               |
| `nacl.tf`             | Creates and associates Network ACLs for public and private subnets.             |
| `flow_logs.tf`        | Configures VPC Flow Logs and related IAM roles and policies.                    |
| `variables.tf`        | Declares input variables for the module.                                        |
| `outputs.tf`          | Exposes key outputs for integration with other modules.                         |

---

## **Input Variables**

| **Name**                         | **Type**       | **Description**                                     | **Default/Required**       |
|----------------------------------|----------------|-----------------------------------------------------|----------------------------|
| `aws_region`                     | `string`       | AWS region where resources will be created.         | **Required**               |
| `aws_account_id`                 | `string`       | AWS account ID for configuring permissions.         | **Required**               |
| `vpc_cidr_block`                 | `string`       | CIDR block for the VPC.                             | **Required**               |
| `name_prefix`                    | `string`       | Prefix for resource names.                          | **Required**               |
| `environment`                    | `string`       | Environment tag (e.g., dev, stage, prod).           | **Required**               |
| `public_subnet_cidr_block_1`     | `string`       | CIDR block for the first public subnet.             | **Required**               |
| `public_subnet_cidr_block_2`     | `string`       | CIDR block for the second public subnet.            | **Required**               |
| `public_subnet_cidr_block_3`     | `string`       | CIDR block for the third public subnet.             | **Required**               |
| `private_subnet_cidr_block_1`    | `string`       | CIDR block for the first private subnet.            | **Required**               |
| `private_subnet_cidr_block_2`    | `string`       | CIDR block for the second private subnet.           | **Required**               |
| `private_subnet_cidr_block_3`    | `string`       | CIDR block for the third private subnet.            | **Required**               |
| `availability_zone_public_1`     | `string`       | Availability zone for the first public subnet.      | **Required**               |
| `availability_zone_public_2`     | `string`       | Availability zone for the second public subnet.     | **Required**               |
| `availability_zone_public_3`     | `string`       | Availability zone for the third public subnet.      | **Required**               |
| `availability_zone_private_1`    | `string`       | Availability zone for the first private subnet.     | **Required**               |
| `availability_zone_private_2`    | `string`       | Availability zone for the second private subnet.    | **Required**               |
| `availability_zone_private_3`    | `string`       | Availability zone for the third private subnet.     | **Required**               |
| `kms_key_arn`                    | `string`       | ARN of KMS key for Flow Logs encryption             | **Required**               |
| `flow_logs_retention_in_days`    | `number`       | Number of days to retain VPC Flow Logs              | **Required**               |
| `ssh_allowed_cidr`               | `list(string)` | List of allowed CIDR blocks for SSH access.         | `["0.0.0.0/0"]` (Optional) |
| `ssm_endpoint_id`                | `string`       | ID of the SSM Interface VPC Endpoint                | **Required**               |
| `ssm_messages_endpoint_id`       | `string`       | ID of the SSM Messages Interface VPC Endpoint       | **Required**               |
| `asg_messages_endpoint_id`       | `string`       | ID of the EC2 ASG Messages Interface Endpoint       | **Required**               |
| `cloudwatch_logs_endpoint_id`    | `string`       | ID of the CloudWatch Logs Interface VPC Endpoint    | **Required**               |
| `kms_endpoint_id`                | `string`       | ID of the KMS Interface VPC Endpoint                | **Required**               |

## **Outputs**

| **Name**                         | **Description**                                                      |
|----------------------------------|----------------------------------------------------------------------|
| `vpc_id`                         | The ID of the created VPC                                            |
| `vpc_cidr_block`                 | The CIDR block of the VPC                                            |
| `public_subnet_1_id`             | ID of the first public subnet                                        |
| `public_subnet_2_id`             | ID of the second public subnet                                       |
| `public_subnet_3_id`             | ID of the third public subnet                                        |
| `private_subnet_1_id`            | ID of the first private subnet                                       |
| `private_subnet_2_id`            | ID of the second private subnet                                      |
| `private_subnet_3_id`            | ID of the third private subnet                                       |
| `public_subnets`                 | List of all public subnet IDs                                        |
| `private_subnets`                | List of all private subnet IDs                                       |
| `public_subnet_ids`              | List of IDs for public subnets                                       |
| `private_subnet_ids`             | List of IDs for private subnets                                      |
| `public_subnet_cidr_block_1`     | CIDR block for the first public subnet                               |
| `public_subnet_cidr_block_2`     | CIDR block for the second public subnet                              |
| `public_subnet_cidr_block_3`     | CIDR block for the third public subnet                               |
| `private_subnet_cidr_block_1`    | CIDR block for the first private subnet                              |
| `private_subnet_cidr_block_2`    | CIDR block for the second private subnet                             |
| `private_subnet_cidr_block_3`    | CIDR block for the third private subnet                              |
| `public_route_table_id`          | ID of the public route table                                         |
| `private_route_table_id`         | ID of the private route table                                        |
| `vpc_flow_logs_log_group_name`   | Name of the CloudWatch Log Group for VPC Flow Logs                   |
| `vpc_flow_logs_role_arn`         | ARN of the IAM Role for VPC Flow Logs                                |
| `s3_endpoint_id`                 | ID of the S3 Gateway Endpoint                                        |
| `dynamodb_endpoint_id`           | ID of the DynamoDB Gateway Endpoint                                  |
| `default_security_group_id`      | The ID of the default security group for the VPC                     |
| `public_subnet_nacl_id`          | The ID of the NACL associated with public subnets                    |
| `private_subnet_nacl_id`         | The ID of the NACL associated with private subnets                   |
| `availability_zone_public_1`     | Availability Zone for public subnet 1                                |
| `availability_zone_public_2`     | Availability Zone for public subnet 2                                |
| `availability_zone_public_3`     | Availability Zone for public subnet 3                                |
| `availability_zone_private_1`    | Availability Zone for private subnet 1                               |
| `availability_zone_private_2`    | Availability Zone for private subnet 2                               |
| `availability_zone_private_3`    | Availability Zone for private subnet 3                               |
| `internet_gateway_id`            | The ID of the Internet Gateway                                       |

---

## **Usage Example**

```hcl
module "vpc" {
  source                        = "./modules/vpc"
  aws_region                    = "eu-west-1"
  aws_account_id                = "123456789012"
  vpc_cidr_block                = "10.0.0.0/16"
  name_prefix                   = "dev"
  environment                   = "development"  # Must be dev, stage, or prod

  # Subnet Configuration
  public_subnet_cidr_block_1    = "10.0.1.0/24"
  public_subnet_cidr_block_2    = "10.0.2.0/24"
  public_subnet_cidr_block_3    = "10.0.3.0/24"
  private_subnet_cidr_block_1   = "10.0.4.0/24"
  private_subnet_cidr_block_2   = "10.0.5.0/24"
  private_subnet_cidr_block_3   = "10.0.6.0/24"

  # Availability Zones - spread across three AZs for high availability
  availability_zone_public_1    = "eu-west-1a"
  availability_zone_public_2    = "eu-west-1b"
  availability_zone_public_3    = "eu-west-1c"
  availability_zone_private_1   = "eu-west-1a"
  availability_zone_private_2   = "eu-west-1b"
  availability_zone_private_3   = "eu-west-1c"

  # Security Configuration
  ssh_allowed_cidr             = ["10.0.0.0/8"]  # Restrict SSH access

  # Flow Logs Configuration
  kms_key_arn                 = aws_kms_key.vpc_logs_key.arn
  flow_logs_retention_in_days = 30     # Adjust based on requirements
  
  # VPC Endpoint IDs from interface_endpoints module
  ssm_endpoint_id             = module.interface_endpoints.ssm_endpoint_id
  ssm_messages_endpoint_id    = module.interface_endpoints.ssm_messages_endpoint_id
  asg_messages_endpoint_id    = module.interface_endpoints.asg_messages_endpoint_id
  cloudwatch_logs_endpoint_id = module.interface_endpoints.cloudwatch_logs_endpoint_id
  kms_endpoint_id             = module.interface_endpoints.kms_endpoint_id
}

# KMS key for Flow Logs encryption
resource "aws_kms_key" "vpc_logs_key" {
  description             = "KMS key for VPC Flow Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "dev-vpc-logs-key"
    Environment = "development"
  }
}

# Interface Endpoints module (referenced in VPC module)
module "interface_endpoints" {
  source = "./modules/interface_endpoints"
  # ... other parameters
}
```

## **Best Practices**

1. **Network Design**:
   - Use all available AZs for high availability
   - Separate public and private subnets
   - Plan CIDR ranges for future growth

2. **Security**:
   - Review NACL rules regularly
   - Monitor Flow Logs for suspicious activity
   - Use KMS encryption for sensitive data

3. **Monitoring**:
   - Set up CloudWatch Alarms
   - Review Flow Logs regularly
   - Monitor subnet IP usage

## **Future Improvements**

1. **VPC Flow Logs Enhancement**:
   - Add support for custom log formats
   - Implement Athena integration for log analysis
   - Add option for S3 as alternative log destination
   - Create default CloudWatch Alarms for common scenarios

2. **Network Configuration**:
   - Add support for Transit Gateway integration
   - Implement VPC peering configuration
   - Add option for custom route table configurations
   - Support for additional Gateway Endpoints

3. **Security Enhancements**:
   - Implement more granular NACL rules
   - Add support for VPC endpoints for additional AWS services
   - Enhanced security group configurations
   - Implement network firewall integration

4. **Monitoring and Maintenance**:
   - Add automated log analysis and reporting
   - Implement cost optimization recommendations
   - Add support for automated backup and recovery
   - Create default CloudWatch dashboards

5. **Documentation and Examples**:
   - Add more usage examples for different scenarios
   - Create architecture diagrams
   - Add troubleshooting guide
   - Include cost estimation guidelines

---

## **Authors**

This module was developed following Terraform best practices, ensuring flexibility, scalability, and security. Contributions and feedback are highly appreciated!

---

## **Useful Resources**

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [Terraform VPC Module Guide](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS Network ACLs Overview](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [VPC Flow Logs Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [CloudWatch Logs Pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)