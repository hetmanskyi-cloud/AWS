# ElastiCache Module for Terraform

This module creates and manages an ElastiCache Redis cluster in AWS, including a replication group, subnet group, CloudWatch alarms for monitoring, and a security group to control access. It is designed to work across multiple environments (`dev`, `stage`, and `prod`) with optimized settings for each environment.

---

### Prerequisites

- **AWS Provider Configuration**:
The AWS region and other parameters of the `aws` provider are specified in the root configuration.

An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **ElastiCache Subnet Group**:
  - Creates a subnet group for deploying ElastiCache nodes in private subnets.
- **Redis Replication Group**:
  - Supports multi-node clusters with replication for high availability.
  - Enables automatic failover for fault tolerance.
  - Includes configurable encryption for enhanced security:
    - **At rest** using AWS KMS.
    - **In transit** for secure data exchange.
  - Snapshot backups with configurable retention periods and time windows.
- **CloudWatch Monitoring**:
  - Alarms for monitoring Redis performance, such as:
    - **High CPU utilization** in `stage` and `prod`.
    - **Low CPU credits** for burstable instances.
    - **Critical free memory** in `dev`.
  - Pessimistic memory thresholds in `dev` are adjusted (reduced by half) to minimize false alarms.
- **Security Group**:
  - Controls inbound Redis access (port 6379) from EC2 instances via referenced Security Group.
  - Allows unrestricted outbound traffic for connectivity.
- **Flexible Configuration**:
  - Configurable Redis version, node type, number of shards, and replica counts.

---

## Files Structure

| **File**               | **Description**                                                               |
|------------------------|-------------------------------------------------------------------------------|
| `main.tf`              | Creates the ElastiCache subnet group, replication group, and parameter group. |
| `security_group.tf`    | Defines the security group for Redis to control network access.               |
| `metrics.tf`           | Configures CloudWatch alarms for monitoring Redis performance.                |
| `variables.tf`         | Declares input variables for the module.                                      |
| `outputs.tf`           | Exposes key outputs for integration with other modules.                       |

---

## Input Variables

| **Name**                             | **Type**       | **Description**                                                               | **Default/Required**  |
|--------------------------------------|----------------|-------------------------------------------------------------------------------|-----------------------|
| `name_prefix`                        | `string`       | Prefix for resource names.                                                    | Required              |
| `environment`                        | `string`       | Environment for the resources (e.g., dev, stage, prod).                       | Required              |
| `vpc_id`                             | `string`       | The VPC ID where the Redis cluster will be created.                           | Required              |
| `private_subnet_ids`                 | `list(string)` | List of private subnet IDs for deploying Redis.                               | Required              |
| `ec2_security_group_id`              | `string`       | Security Group ID of EC2 instances that require access to Redis.              | Required              |
| `redis_version`                      | `string`       | Redis version (e.g., '7.1').                                                  | Required              |
| `node_type`                          | `string`       | Node type for Redis (e.g., 'cache.t3.micro').                                 | Required              |
| `replicas_per_node_group`            | `number`       | Number of replicas per shard.                                                 | Required              |
| `num_node_groups`                    | `number`       | Number of shards (node groups).                                               | Required              |
| `redis_port`                         | `number`       | Port number for Redis (default: 6379).                                        | `6379`                |
| `snapshot_retention_limit`           | `number`       | Number of snapshot backups to retain.                                         | Required              |
| `snapshot_window`                    | `string`       | Preferred time window for taking snapshots (e.g., '03:00-04:00').             | `03:00-04:00`         |
| `redis_cpu_threshold`                | `number`       | CPU utilization threshold for CloudWatch alarms.                              | Required              |
| `redis_memory_threshold`             | `number`       | Freeable memory threshold (in bytes) for CloudWatch alarms.                   | Required              |
| `sns_topic_arn`                      | `string`       | ARN of the SNS topic for sending CloudWatch alarm notifications.              | Required              |
| `kms_key_arn`                        | `string`       | ARN of the KMS key for encrypting data at rest.                               | Required              |

---

## Outputs

| **Name**                        | **Description**                                        |
|---------------------------------|--------------------------------------------------------|
| `redis_port`                    | The port number for Redis connections.                 |
| `redis_endpoint`                | The primary endpoint for connecting to Redis.          |
| `redis_security_group_id`       | The ID of the Security Group created for Redis access. |

---

## Usage Example

```hcl
module "elasticache" {
  source                  = "./modules/elasticache"
  name_prefix             = "dev"
  environment             = "dev"
  vpc_id                  = "vpc-0123456789abcdef0"
  private_subnet_ids      = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  ec2_security_group_id   = "sg-0123456789abcdef0"
  redis_version           = "7.1"
  node_type               = "cache.t2.micro"
  replicas_per_node_group = 1
  num_node_groups         = 1
  redis_port              = 6379
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-04:00"
  redis_cpu_threshold     = 80
  redis_memory_threshold  = 214748364
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  kms_key_arn             = "arn:aws:kms:eu-west-1:123456789012:key/example-key"
}

output "redis_endpoint" {
  value = module.elasticache.redis_endpoint
}

---

## Notes

1. **Monitoring Strategy**:
   - In `dev`: Only critical **FreeableMemory** alarm is enabled with a less strict threshold (`redis_memory_threshold / 2`) to reduce noise and costs.
   - In `stage` and `prod`: Full monitoring is enabled, including:
     - **High CPU Utilization**.
     - **Low CPU Credit Balance** (important for burstable instance types like `cache.t3.micro`).
2. **Security**:
   - Encryption at rest and in transit is enabled by default for secure Redis deployments.
   - The Security Group restricts inbound Redis access to EC2 instances only.
3. **Flexibility**:
   - All configuration parameters (e.g., thresholds, node type, backups) are customizable via input variables.

---

## Future Improvements

1. Add support for additional ElastiCache engines (e.g., Memcached).
2. Integrate CloudWatch Alarms with AWS Lambda for automatic remediation.
3. Allow conditional creation of Security Groups for reuse across modules.

---

## Authors

This module was crafted following Terraform best practices, focusing on security, scalability, and maintainability. Contributions and feedback are welcome!

---

## Useful Resources

- [Amazon ElastiCache Documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/WhatIs.html)
- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS KMS Encryption](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

---