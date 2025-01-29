# VPC Endpoints Module for Terraform

This module creates and manages VPC Interface Endpoints for various AWS services within a specified VPC. It also configures optional CloudWatch Logs for monitoring VPC Endpoint traffic and sets up the necessary Security Groups to control access. Gateway Endpoints (S3 and DynamoDB) are managed by the `vpc` module.

---

### Prerequisites

- **AWS Provider Configuration**:
  Ensure that the `aws` provider is configured with the appropriate region and credentials.

- **Existing VPC and Subnets**:
  The module requires an existing VPC and subnets where the Interface Endpoints will be deployed.

- **KMS Key**:
  A KMS key is required if CloudWatch Logs are enabled.

---

## Features

- **Creates VPC Interface Endpoints**:
  - **SSM Endpoints**: 
    - SSM Endpoint for AWS Systems Manager
    - SSM Messages Endpoint for Systems Manager Agent
    - ASG Messages Endpoint for EC2 instance communications
  - **Lambda Endpoint**: For serverless function integration
  - **CloudWatch Logs Endpoint**: For log delivery
  - **SQS Endpoint**: For message queue access
  - **KMS Endpoint**: For encryption operations
  - All endpoints are configured with private DNS enabled

- **Optional CloudWatch Logs Integration**:
  - Creates a CloudWatch Log Group for monitoring VPC Endpoint traffic
  - Configurable retention period
  - KMS encryption for logs when enabled

- **Security Group Configuration**:
  - Creates a dedicated Security Group for VPC Endpoints
  - Ingress rules allow HTTPS (port 443) from VPC CIDR
  - Egress rules allow HTTPS to AWS services and PrivateLink endpoints

- **Resource Tagging**:
  - Consistent tagging across all resources
  - Environment-specific tags
  - Resource identification tags

---

## Files Structure

| **File**              | **Description**                                                                                  |
|-----------------------|--------------------------------------------------------------------------------------------------|
| `main.tf`             | Defines VPC Interface Endpoints with their configurations                                        |
| `cloudwatch_logs.tf`  | Manages CloudWatch Log Group with optional KMS encryption                                        |
| `security_group.tf`   | Configures Security Group with HTTPS access rules                                                |
| `variables.tf`        | Declares and validates input variables                                                           |
| `outputs.tf`          | Provides endpoint IDs, DNS names, and other resource identifiers                                 |

---

## Input Variables

| **Name**                              | **Type**       | **Description**                              | **Default/Required**                                          |
|---------------------------------------|----------------|----------------------------------------------|---------------------------------------------------------------|
| `aws_region`                          | `string`       | AWS region for resource creation.            | **Required**                                                  |
| `aws_account_id`                      | `string`       | AWS account ID for permissions/policies.     | **Required**                                                  |
| `name_prefix`                         | `string`       | Prefix for resource names.                   | **Required**                                                  |
| `environment`                         | `string`       | Environment label (dev, stage, prod).        | **Required**                                                  |
| `vpc_id`                              | `string`       | VPC ID for endpoint creation.                | **Required**                                                  |
| `vpc_cidr_block`                      | `string`       | CIDR block of the VPC.                       | **Required**                                                  |
| `private_subnet_ids`                  | `list(string)` | Private subnet IDs for Interface Endpoints.  | **Required**                                                  |
| `public_subnet_ids`                   | `list(string)` | Public subnet IDs for Interface Endpoints.   | `[]` (Optional)                                               |
| `kms_key_arn`                         | `string`       | KMS key ARN for log encryption.              | **Required** if `enable_cloudwatch_logs_for_endpoints` = true |
| `enable_cloudwatch_logs_for_endpoints`| `bool`         | Enable CloudWatch Logs for VPC Endpoints.    | `false` (Optional)                                            |
| `endpoints_log_retention_in_days`     | `number`       | Retention period for logs (days).            | `7` (Optional)                                                |

---

## Outputs

| **Name**                          | **Description**                                          |
|----------------------------------|-----------------------------------------------------------|
| `ssm_endpoint_id`                | ID of the SSM Interface Endpoint                          |
| `ssm_messages_endpoint_id`       | ID of the SSM Messages Interface Endpoint                 |
| `asg_messages_endpoint_id`       | ID of the ASG Messages Interface Endpoint                 |
| `lambda_endpoint_id`             | ID of the Lambda Interface Endpoint                       |
| `cloudwatch_logs_endpoint_id`    | ID of the CloudWatch Logs Interface Endpoint              |
| `sqs_endpoint_id`                | ID of the SQS Interface Endpoint                          |
| `kms_endpoint_id`                | ID of the KMS Interface Endpoint                          |
| `*_endpoint_dns_names`           | DNS names for each Interface Endpoint                     |
| `endpoints_state`                | State of all VPC endpoints                                |
| `endpoint_security_group_id`     | ID of the security group for VPC endpoints                |
| `endpoints_log_group_arn`        | ARN of the CloudWatch Log Group (if enabled)              |
| `endpoints_log_group_name`       | Name of the CloudWatch Log Group (if enabled)             |

---

## Usage Example

```hcl
module "vpc_endpoints" {
  source = "./modules/endpoints"
  
  aws_region                 = var.aws_region
  aws_account_id            = var.aws_account_id
  environment               = var.environment
  name_prefix               = var.name_prefix
  
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr_block           = module.vpc.vpc_cidr_block
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  
  kms_key_arn              = module.kms.kms_key_arn

  enable_cloudwatch_logs_for_endpoints = true
  endpoints_log_retention_in_days      = 30
}
```

---

## Security Best Practices

- **Network Security**:
  - HTTPS-only communication (port 443)
  - Access restricted to VPC CIDR
  - Private DNS enabled for all endpoints

- **Encryption**:
  - Optional KMS encryption for logs
  - Integration with AWS KMS service
  - Secure communication via HTTPS

- **Monitoring**:
  - Optional CloudWatch Logs
  - Configurable log retention
  - Endpoint state tracking

---

## Integration with Other Modules

- **VPC Module**:
  - Provides networking infrastructure
  - Manages Gateway Endpoints (S3, DynamoDB)
  - Supplies subnet IDs and CIDR blocks

- **KMS Module**:
  - Provides encryption keys
  - Manages key policies
  - Enables log encryption

- **S3 Module**:
  - Uses endpoints for Lambda function
  - Integrates with CloudWatch Logs
  - Utilizes KMS encryption

---

### Useful Resources

- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)
- [AWS Lambda VPC Access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [AWS CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- [AWS SQS](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-vpc-endpoints.html)
- [AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/kms-vpc-endpoint.html)