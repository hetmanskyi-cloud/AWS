# AWS VPC Module for Terraform

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Prerequisites / Requirements](#2-prerequisites--requirements)
- [3. Architecture Diagram](#3-architecture-diagram)
- [4. Features](#4-features)
- [5. Design Assumptions and Limitations](#5-design-assumptions-and-limitations)
- [6. Module Architecture](#6-module-architecture)
- [7. Module Files Structure](#7-module-files-structure)
- [8. Inputs](#8-inputs)
- [9. Outputs](#9-outputs)
- [10. Example Usage](#10-example-usage)
- [11. Security Considerations / Recommendations](#11-security-considerations--recommendations)
- [12. Conditional Resource Creation](#12-conditional-resource-creation)
- [13. Best Practices](#13-best-practices)
- [14. Integration](#14-integration)
- [15. Future Improvements](#15-future-improvements)
- [16. Troubleshooting and Common Issues](#16-troubleshooting-and-common-issues)
- [17. Notes](#17-notes)
- [18. Useful Resources](#18-useful-resources)

---

## 1. Overview

This module creates and manages a Virtual Private Cloud (VPC) in AWS, including public and private subnets, route tables, an Internet Gateway, optional NAT Gateways, Network ACLs (NACLs), and VPC Flow Logs. It provides a secure, scalable, and configurable networking foundation for AWS infrastructure, built with modern Terraform practices.

---

## 2. Prerequisites / Requirements

- **AWS Provider Configuration**:
  - The AWS provider (`aws`) must be properly configured in the root module with region and credentials.

- **KMS Key for Flow Logs**:
  - An existing KMS key ARN is required for encrypting VPC Flow Logs.

---

## 3. Architecture Diagram

```mermaid
graph LR
    %% Main VPC Component
    VPC["VPC<br/>(CIDR Block)"]

    %% Internet Gateway
    IGW["Internet Gateway"]
    NAT["NAT Gateway(s)<br/>(Optional)"]

    %% Subnets
    subgraph "Public Subnets"
        PubSub["Public Subnets<br/>(Dynamic via for_each)"]
    end

    subgraph "Private Subnets"
        PrivSub["Private Subnets<br/>(Dynamic via for_each)"]
    end

    %% Route Tables
    PubRT["Public Route Table"]
    PrivRT["Private Route Tables<br/>(One per AZ)"]

    %% NACLs
    PubNACL["Public NACL"]
    PrivNACL["Private NACL"]

    %% VPC Endpoints
    S3EP["S3 Gateway Endpoint"]
    DynamoEP["DynamoDB Gateway Endpoint"]

    %% Flow Logs and Monitoring
    FlowLogs["VPC Flow Logs"]
    LogGroup["CloudWatch Log Group<br/>(KMS Encrypted)"]
    CWAlarm["CloudWatch Alarm<br/>(Flow Logs Delivery Errors)"]
    SNS["SNS Topic<br/>(Optional)"]

    %% IAM Components for Flow Logs
    IAMRole["IAM Role<br/>(VPC Flow Logs)"]
    IAMPolicy["IAM Policy<br/>(CloudWatch Logs)"]

    %% Default Security Group
    DefSG["Default Security Group<br/>(Locked Down)"]

    %% Connections
    VPC --> IGW
    VPC --> PubSub & PrivSub
    VPC --> S3EP & DynamoEP
    VPC -->|"Captures Traffic"| FlowLogs
    VPC --> DefSG

    PubSub -->|"Hosts"| NAT
    PubSub -->|"Associated with"| PubRT
    PrivSub -->|"Associated with"| PrivRT

    PubSub -->|"Protected by"| PubNACL
    PrivSub -->|"Protected by"| PrivNACL

    PubRT -->|"Routes to"| IGW
    PrivRT -->|"Routes to"| NAT
    PubRT -->|"Routes to"| S3EP & DynamoEP
    PrivRT -->|"Routes to"| S3EP & DynamoEP

    FlowLogs -->|"Stores in"| LogGroup
    LogGroup -->|"Monitored by"| CWAlarm
    CWAlarm -->|"Notifies"| SNS

    %% IAM Connections
    IAMRole -->|"Assumes"| IAMPolicy
    IAMPolicy -->|"Grants Access"| LogGroup
    FlowLogs -->|"Uses"| IAMRole

    %% Styling
    classDef primary fill:#FF9900,stroke:#232F3E,color:white
    classDef networking fill:#3F8624,stroke:#232F3E,color:white
    classDef security fill:#DD3522,stroke:#232F3E,color:white
    classDef monitoring fill:#7D3C98,stroke:#232F3E,color:white
    classDef iam fill:#0066CC,stroke:#232F3E,color:white
    classDef endpoints fill:#1E8449,stroke:#232F3E,color:white

    class VPC,IGW,NAT primary
    class PubSub,PrivSub,PubRT,PrivRT networking
    class PubNACL,PrivNACL,DefSG security
    class FlowLogs,LogGroup,CWAlarm,SNS monitoring
    class IAMRole,IAMPolicy iam
    class S3EP,DynamoEP endpoints
```

> _Diagram generated with [Mermaid](https://mermaid.js.org/)_

---

## 4. Features

- **VPC Creation**: Creates a VPC with a configurable CIDR block and DNS support.
- **Dynamic Subnet Management**: Configures any number of public and private subnets across multiple availability zones using a map-based variable.
- **Routing**:
    - Creates a single route table for all public subnets with a default route to an Internet Gateway.
    - Creates one route table per Availability Zone, shared by all private subnets within that AZ.
- **NAT Gateway**:
    - Optional support for NAT Gateways to provide outbound internet access for private subnets.
    - Supports both a single NAT Gateway for the VPC or a highly-available setup with one NAT Gateway per unique Availability Zone where public subnets are defined.
- **Network ACLs (NACLs)**:
    - Configurable rules for controlling inbound and outbound traffic for public and private subnets.
- **VPC Flow Logs**:
    - Captures all traffic (ACCEPT/REJECT) and sends it to a KMS-encrypted CloudWatch Log Group.
    - Includes a CloudWatch Alarm to monitor for log delivery errors.
- **Gateway Endpoints**: Configurable S3 and DynamoDB endpoints for private access from all subnets.
- **Security**: Locks down the default security group by removing all default rules.
- **Dynamic NACLs**: Network ACLs and their rules are dynamically configurable via input variables, allowing for flexible security postures without modifying the module code.

---

## 5. Design Assumptions and Limitations

### Network Symmetry for HA NAT Gateways

This module's High Availability (HA) NAT Gateway configuration (`single_nat_gateway = false`) operates on a crucial assumption: **network symmetry**.

- **The Logic**: In HA mode, the module creates one NAT Gateway per Availability Zone (AZ) where a public subnet exists. Private subnets are then routed to the NAT Gateway located in their own AZ. The lookup for the correct NAT Gateway is performed using the private subnet's AZ.
- **The Requirement**: For this to work, **if you define a private subnet in a specific AZ (e.g., `eu-west-1c`), you MUST also define at least one public subnet in that same AZ (`eu-west-1c`)**.
- **The Risk**: If you create a private subnet in an AZ that has no public subnets, Terraform will fail during the `plan` or `apply` phase. It will be unable to find a corresponding NAT Gateway for that private subnet's route table, resulting in a "Key not found" error.

**Example Failure Scenario:**

```hcl
# This configuration WILL FAIL
public_subnets = {
  "1a" = { availability_zone = "eu-west-1a", ... },
  "1b" = { availability_zone = "eu-west-1b", ... }
}
private_subnets = {
  "1a" = { availability_zone = "eu-west-1a", ... },
  "1b" = { availability_zone = "eu-west-1b", ... },
  "1c" = { availability_zone = "eu-west-1c", ... } # <--- FAILS HERE. No public subnet in 1c.
}
```

---

## 6. Module Architecture

This module provisions the following AWS resources:
- **VPC** with a customizable CIDR block.
- **Public and Private Subnets** created dynamically based on input variables.
- **Internet Gateway** for public internet access.
- **NAT Gateway(s)** and **Elastic IPs** (optional) for private outbound access.
- **Route Tables** for public and private routing logic.
- **Network ACLs (NACLs)** with detailed inbound/outbound rules.
- **VPC Gateway Endpoints** for S3 and DynamoDB.
- **VPC Flow Logs** with a CloudWatch Log Group and KMS encryption.
- **CloudWatch Alarm** for Flow Logs delivery errors.
- **IAM Role and Policy** for Flow Logs permissions.
- **Default Security Group** with all rules removed.

---

## 7. Module Files Structure

| **File**          | **Description**                                                                   |
|-------------------|-----------------------------------------------------------------------------------|
| `main.tf`         | Defines the VPC, subnets, and default security group.                             |
| `network.tf`      | Configures IGW, NAT Gateways, Route Tables, associations, and Gateway Endpoints.  |
| `nacl.tf`         | Creates and associates Network ACLs for public and private subnets.               |
| `flow_logs.tf`    | Configures VPC Flow Logs, related IAM roles, policies, and CloudWatch alarms.     |
| `variables.tf`    | Declares input variables for the module.                                          |
| `outputs.tf`      | Exposes key outputs for integration with other modules.                           |
| `versions.tf`     | Defines required Terraform and provider versions.                                 |

---

## 8. Inputs

| **Name**                      | **Type**        | **Description**                                                                  |
|-------------------------------|-----------------|----------------------------------------------------------------------------------|
| `aws_region`                  | `string`        | AWS region for resource creation.                                                |
| `aws_account_id`              | `string`        | AWS account ID for policy permissions.                                           |
| `vpc_cidr_block`              | `string`        | The CIDR block for the VPC.                                                      |
| `name_prefix`                 | `string`        | Prefix for resource names.                                                       |
| `environment`                 | `string`        | Deployment environment (e.g., `dev`, `stage`, `prod`).                           |
| `tags`                        | `map(string)`   | Tags to apply to all resources.                                                  |
| `enable_nat_gateway`          | `bool`          | Enable NAT Gateway for private subnets.                                          |
| `single_nat_gateway`          | `bool`          | Use a single NAT Gateway for all AZs.                                            |
| `public_subnets`              | `map(object)`   | Map of public subnets to create.                                                 |
| `private_subnets`             | `map(object)`   | Map of private subnets to create.                                                |
| `kms_key_arn`                 | `string`        | KMS key ARN for Flow Log encryption.                                             |
| `flow_logs_retention_in_days` | `number`        | Retention period for VPC Flow Logs.                                              |
| `sns_topic_arn`               | `string`        | SNS topic ARN for CloudWatch alarm notifications.                                |
| `enable_dns_hostnames`        | `bool`          | Set to true to ensure that instances launched in the VPC get DNS hostnames.      |
| `enable_dns_support`          | `bool`          | Set to true to ensure that DNS resolution is supported for the VPC.              |
| `vpc_flow_log_traffic_type`   | `string`        | The type of traffic to capture in VPC Flow Logs (`ALL`, `ACCEPT`, or `REJECT`).  |
| `public_nacl_rules`           | `map(object)`   | A map of objects defining the ingress and egress rules for the public NACL.      |
| `private_nacl_rules`          | `map(object)`   | A map of objects defining the ingress and egress rules for the private NACL.     |

---

## 9. Outputs

| **Name**                       | **Description**                                                                  |
|--------------------------------|----------------------------------------------------------------------------------|
| `vpc_id`                       | The ID of the VPC.                                                               |
| `vpc_arn`                      | The ARN of the VPC.                                                              |
| `vpc_cidr_block`               | The CIDR block of the VPC.                                                       |
| `public_subnet_ids`            | List of IDs of public subnets.                                                   |
| `private_subnet_ids`           | List of IDs of private subnets.                                                  |
| `public_subnets_map`           | A map of public subnets with their details (id, cidr_block, availability_zone).  |
| `private_subnets_map`          | A map of private subnets with their details (id, cidr_block, availability_zone). |
| `nat_gateway_public_ips`       | List of public Elastic IP addresses assigned to the NAT Gateways.                |
| `public_route_table_id`        | ID of the public route table.                                                    |
| `private_route_table_ids`      | A map of private route table IDs, keyed by Availability Zone.                    |
| `s3_endpoint_id`               | The ID of the S3 Gateway Endpoint.                                               |
| `dynamodb_endpoint_id`         | The ID of the DynamoDB VPC Endpoint.                                             |
| `default_security_group_id`    | The ID of the default security group for the VPC.                                |
| `vpc_flow_logs_log_group_name` | Name of the CloudWatch Log Group for VPC Flow Logs.                              |

---

## 10. Example Usage

```hcl
module "vpc" {
  source     = "./modules/vpc"
  aws_region = "eu-west-1"
  aws_account_id   = "123456789012"
  vpc_cidr_block   = "10.0.0.0/16"
  name_prefix      = "my-app"
  environment      = "dev"

  # Enable NAT Gateway for private subnets (HA setup)
  enable_nat_gateway = true
  single_nat_gateway = false

  public_subnets = {
    "1a" = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "eu-west-1a"
    },
    "1b" = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "eu-west-1b"
    },
    "1c" = {
      cidr_block        = "10.0.3.0/24"
      availability_zone = "eu-west-1c"
    }
  }

  private_subnets = {
    "1a" = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "eu-west-1a"
    },
    "1b" = {
      cidr_block        = "10.0.20.0/24"
      availability_zone = "eu-west-1b"
    },
    "1c" = {
      cidr_block        = "10.0.30.0/24"
      availability_zone = "eu-west-1c"
    }
  }

  # Flow Logs Configuration
  kms_key_arn                 = module.kms.key_arn
  flow_logs_retention_in_days = 30
  sns_topic_arn               = aws_sns_topic.default.arn
}
```
---

## 11. Security Considerations / Recommendations

This module includes several security-related configurations that should be carefully reviewed and adjusted for production environments.

1.  **Network ACLs (NACLs)**:
    *   The Public NACL rules are permissive by default to allow for ease of use in development environments. **These should be tightened for production.**
    *   **Inbound HTTP/HTTPS from `0.0.0.0/0`**: This is required for public-facing ALBs but exposes the entire subnet. For resources that do not need public inbound access, use private subnets.
    *   **Inbound Ephemeral Ports from `0.0.0.0/0`**: The rule `public_inbound_ephemeral` allows return traffic from any source. This is overly permissive and should be restricted if possible.
    *   **Outbound `0.0.0.0/0`**: The public outbound NACL allows all traffic to all destinations. For a more secure posture, restrict this to only necessary protocols and destinations.

2.  **Public IP Assignment**:
    *   Public subnets are configured with `map_public_ip_on_launch = true`. This means any EC2 instance launched in a public subnet will get a public IP address.
    *   **Recommendation**: For production, consider setting this to `false` and using a bastion host or AWS SSM Session Manager for administrative access to instances, reducing the public attack surface.

3.  **Flow Logs Security**:
    *   KMS encryption is enforced for all log data at rest.
    *   The IAM role for Flow Logs follows the principle of least privilege.
    *   A CloudWatch alarm monitors for and alerts on log delivery failures, ensuring security visibility is maintained.

4.  **NAT Gateways**:
    *   For production environments, always use the highly-available setup (`single_nat_gateway = false`) to ensure a resilient NAT Gateway in each unique Availability Zone for outbound internet connectivity from private subnets.
    *   The module now includes a validation rule to ensure that if HA NAT Gateways are enabled, each private subnet's Availability Zone has a corresponding public subnet to host a NAT Gateway.
    *   Be aware that NAT Gateways incur costs per hour and per gigabyte of data processed.

5.  **Default Security Group**:
    *   The module intentionally locks down the default security group by removing all ingress and egress rules. This forces the explicit definition of all required traffic via custom security groups, adhering to a "deny by default" security posture.

---

## 12. Conditional Resource Creation

- **NAT Gateways**: `aws_eip` and `aws_nat_gateway` resources are created only if `enable_nat_gateway` is set to `true`.
- **CloudWatch Alarm for Flow Logs**: The `aws_cloudwatch_metric_alarm` resource for monitoring Flow Log delivery errors is created unconditionally. However, the `alarm_actions` that trigger SNS notifications are only attached if a non-null `sns_topic_arn` is provided. If the variable is `null`, the alarm exists but will not send notifications.

---

## 13. Best Practices

1. **High Availability**: For production workloads, create subnets in multiple Availability Zones and set `single_nat_gateway = false`. Ensure that every Availability Zone hosting a private subnet also has a public subnet for resilient outbound connectivity via NAT Gateways. This is enforced by a validation rule.
2. **Security**: Regularly review NACL rules. Monitor VPC Flow Logs for suspicious activity.
3. **Scalability**: Use a logical naming convention for your subnet maps (e.g., "1a", "1b") to keep routing and associations clear.
4. **Least Privilege**: Always start with the most restrictive NACL and security group rules possible and only open up traffic as needed.

---

## 14. Integration

This VPC module is designed to integrate with:
- **ALB Module** — for public access to application load balancers.
- **ASG Module** — for EC2 auto-scaling groups deployed in the subnets.
- **RDS Module** — for database instances located in private subnets.
- **ElastiCache Module** — for in-memory caching layers inside private subnets.

---

## 15. Future Improvements

- Implement **Transit Gateway integration** for multi-VPC architecture.
- Add **custom DHCP options set** support.
- Extend VPC Flow Logs with **Athena query support** for deeper analysis.
- Provide **IPv6 support** for modern workloads.

---

## 16. Troubleshooting and Common Issues

This section outlines common issues and provides AWS CLI commands to help diagnose them.

### 1. No Internet Access in Public Subnets
**Cause:** Missing or incorrect route to the Internet Gateway (IGW).
**Solution:** Verify the public route table has a route for `0.0.0.0/0` pointing to the IGW ID.
```bash
aws ec2 describe-route-tables --filters Name=tag:Name,Values=<name_prefix>-public-rt-<environment>
```

### 2. No Outbound Internet from Private Subnets
**Cause:** NAT Gateway is disabled, or routing is incorrect.
**Solution:**
- Ensure `enable_nat_gateway = true`.
- Check that the private route table for the specific AZ has a `0.0.0.0/0` route pointing to the correct NAT Gateway ID.
- Verify the private NACL allows outbound HTTPS traffic.
```bash
aws ec2 describe-route-tables --filters Name=tag:Name,Values=<name_prefix>-private-rtb-<az>-<environment>
```

### 3. Flow Logs Delivery Errors
**Cause:** IAM Role or KMS key policy permissions are incorrect.
**Solution:**
- Verify the IAM role policy allows `logs:PutLogEvents`.
- Ensure the KMS key policy allows the `vpc-flow-logs.amazonaws.com` service principal.
- Check the CloudWatch Alarm status for `FlowLogsDeliveryErrors`.

### 4. AWS CLI Reference
```bash
# List VPCs
aws ec2 describe-vpcs --filters Name=tag:Name,Values=<name_prefix>-vpc-<environment>

# List Subnets in a VPC
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id>

# Describe NAT Gateways
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<vpc-id>

# Describe NACLs
aws ec2 describe-network-acls --filters Name=vpc-id,Values=<vpc-id>

# Describe VPC Endpoints
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<vpc-id>

# Tail logs in real time
aws logs tail /aws/vpc/flow-logs/<env> --follow
```
> Replace `<vpc-id>`, `<name_prefix>`, `<environment>`, etc., with actual values.

---

## 17. Notes
- All subnets and routing are now created dynamically. Ensure your `public_subnets` and `private_subnets` variable maps are structured correctly.
- For High Availability, ensure you have subnets in multiple AZs and set `single_nat_gateway = false`.
- NACL rule numbers are hardcoded and spaced to allow for future additions.
- The commented-out ICMP rule in `nacl.tf` can be enabled for network diagnostics (e.g., `ping`).

---

## 18. Useful Resources

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [VPC Flow Logs Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

---
