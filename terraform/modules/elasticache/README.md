# ElastiCache Module for Terraform

This module creates and manages an ElastiCache Redis cluster in AWS, including a replication group, subnet group, CloudWatch alarms for monitoring, and a security group to control access. It is designed to be flexible and configurable for various deployment requirements.

---

## **Features**

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
  - Configurable alarms for monitoring Redis performance:
    - **High CPU utilization**.
    - **Low CPU credits** for burstable instances.
    - **Critical free memory**.
    - **Replication bytes used** to detect memory issues in replication.
  - Thresholds can be customized via variables.
- **Security Group**:
  - Controls inbound Redis access (port 6379) from ASG instances via a referenced security group.
  - Allows unrestricted outbound traffic for connectivity.
- **KMS Integration**:
  - Uses an existing KMS Key ARN for data encryption.
  - Permissions for the key are managed externally (e.g., in the KMS module's key policy).
- **Free Tier Compatibility**:
  - The default node type (`t2.micro`) is included in AWS Free Tier, making it ideal for testing and small-scale deployments.
- **Flexible Configuration**:
  - Configurable Redis version, node type, number of shards, and replica counts.

---

## **File Structure**

| **File**              | **Description**                                                                 |
|-----------------------|---------------------------------------------------------------------------------|
| `main.tf`             | Creates the ElastiCache subnet group, replication group, and parameter group.   |
| `security_group.tf`   | Defines the security group for Redis and manages network access.                |
| `metrics.tf`          | Configures CloudWatch alarms for monitoring Redis performance.                  |
| `variables.tf`        | Declares input variables for the module.                                        |
| `outputs.tf`          | Exposes key outputs for integration with other modules.                         |

---

## **Input Variables**

| **Name**                               | **Type**       | **Description**                                                          | **Default/Required**       |
|----------------------------------------|----------------|--------------------------------------------------------------------------|----------------------------|
| `name_prefix`                          | `string`       | Prefix for resource names.                                               | **Required**               |
| `vpc_id`                               | `string`       | The VPC ID where the Redis cluster will be created.                      | **Required**               |
| `private_subnet_ids`                   | `list(string)` | List of private subnet IDs for deploying Redis.                          | **Required**               |
| `asg_security_group_id`                | `string`       | Security Group ID for ASG instances allowed to access Redis.             | **Required**               |
| `redis_version`                        | `string`       | Redis version (e.g., '7.1').                                             | **Required**               |
| `node_type`                            | `string`       | Node type for Redis (e.g., 'cache.t3.micro').                            | **Required**               |
| `replicas_per_node_group`              | `number`       | Number of replicas per shard.                                            | **Required**               |
| `num_node_groups`                      | `number`       | Number of shards (node groups).                                          | **Required**               |
| `enable_failover`                      | `bool`         | Enable or disable automatic failover.                                    | `false` (Optional)         |
| `redis_port`                           | `number`       | Port number for Redis (default: 6379).                                   | `6379` (Optional)          |
| `snapshot_retention_limit`             | `number`       | Number of snapshot backups to retain.                                    | **Required**               |
| `snapshot_window`                      | `string`       | Preferred time window for taking snapshots.                              | `"03:00-04:00"` (Optional) |
| `redis_cpu_threshold`                  | `number`       | CPU utilization threshold for CloudWatch alarms.                         | **Required**               |
| `redis_memory_threshold`               | `number`       | Freeable memory threshold (in bytes) for CloudWatch alarms.              | **Required**               |
| `redis_replication_bytes_threshold`    | `number`       | Threshold for triggering replication bytes used alarms (in bytes).       | `50000000` (Optional)      |
| `sns_topic_arn`                        | `string`       | ARN of the SNS topic for CloudWatch alarm notifications.                 | **Required**               |
| `kms_key_arn`                          | `string`       | ARN of the KMS key for encrypting data at rest.                          | **Required**               |
| `enable_redis_low_memory_alarm`        | `bool`         | Toggle for enabling the low memory CloudWatch alarm.                     | `false` (Optional)         |
| `enable_redis_high_cpu_alarm`          | `bool`         | Toggle for enabling the high CPU usage CloudWatch alarm.                 | `false` (Optional)         |
| `enable_redis_evictions_alarm`         | `bool`         | Toggle for enabling the evictions CloudWatch alarm.                      | `false` (Optional)         |
| `enable_redis_replication_bytes_alarm` | `bool`         | Toggle for enabling the replication bytes used CloudWatch alarm.         | `false` (Optional)         |
| `enable_redis_low_cpu_credits_alarm`   | `bool`         | Toggle for enabling the low CPU credits CloudWatch alarm.                | `false` (Optional)         |

**Notes**:
- The `kms_key_arn` must be provided by the KMS module for encryption at rest.
- `replication_bytes` alarms are only applicable when replicas are enabled.

---

## **Outputs**

| **Name**                    | **Description**                                       |
|-----------------------------|-------------------------------------------------------|
| `redis_port`                | The port number for Redis connections.                |
| `redis_endpoint`            | The primary endpoint for connecting to Redis.         |
| `redis_security_group_id`   | The ID of the security group created for Redis access.|
| `redis_replication_group_id`| The ID of the Redis replication group.                |
| `failover_status`           | Indicates if failover is enabled for Redis.           |

---

## **Usage Example**

```hcl
module "elasticache" {
  source                   = "./modules/elasticache"
  name_prefix              = "dev"
  vpc_id                   = "vpc-0123456789abcdef0"
  private_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  asg_security_group_id    = "sg-0123456789abcdef0"
  redis_version            = "7.1"
  node_type                = "cache.t2.micro"
  replicas_per_node_group  = 1
  num_node_groups          = 2
  enable_failover          = true
  redis_port               = 6379
  snapshot_retention_limit = 7
  snapshot_window          = "03:00-04:00"
  redis_cpu_threshold      = 80
  redis_memory_threshold   = 2147483648
  redis_replication_bytes_threshold = 50000000
  sns_topic_arn            = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  kms_key_arn              = "arn:aws:kms:eu-west-1:123456789012:key/example"
}
```

---

## **Notes**

### Monitoring
- Critical alarms are controlled using variables like `enable_redis_low_memory_alarm` and `enable_redis_replication_bytes_alarm`.
- Default thresholds can be adjusted for specific application needs.
  
### Security
- Encryption at rest and in transit is enabled by default, ensuring secure deployments.
- Ingress rules restrict access to Redis only from ASG instances.

### Flexibility
- All parameters (e.g., node type, replicas, thresholds) are configurable via variables, allowing seamless scaling from testing to production.

---

## **Future Improvements**
1. Add support for additional ElastiCache engines (e.g., Memcached).
2. Integrate with AWS Lambda for automated incident response.
3. Evaluate the use of Redis Cluster Mode for scenarios with high data volumes or performance demands, and expand the module's capabilities to support sharded deployments if needed.

---

## Authors

This module was crafted following Terraform best practices, focusing on security, scalability, and maintainability. Contributions and feedback are welcome!

---

## Useful Resources

- [Amazon ElastiCache Documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/WhatIs.html)
- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS KMS Encryption](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

---