# ElastiCache Module for Terraform

This module creates and manages an ElastiCache Redis cluster in AWS, including a replication group, subnet group, CloudWatch alarms for monitoring, and a security group to control access. It is designed to be flexible and configurable for various deployment requirements.

---

## **Features**

- **ElastiCache Subnet Group**:
  - Creates a dedicated subnet group for deploying ElastiCache nodes
  - Supports multiple private subnets for high availability
  - Proper tagging for resource identification

- **Redis Replication Group**:
  - Configurable Redis version with validation (e.g., '7.1')
  - Flexible node type selection (e.g., 'cache.t2.micro', 'cache.t3.micro')
  - Multi-node architecture with configurable:
    - Number of shards (node groups)
    - Replicas per shard
  - Automatic failover capability (when replicas exist)
  - Encryption:
    - At-rest using AWS KMS
    - In-transit enabled by default
  - Configurable port (default: 6379)
  - Lifecycle protection against accidental deletion

- **Parameter Group Management**:
  - Automatic Redis family selection based on version
  - Default parameters optimized for most use cases

- **Backup Configuration**:
  - Configurable snapshot retention period
  - Customizable backup window with format validation

- **CloudWatch Monitoring**:
  - Comprehensive alarm system with:
    - Low memory detection
    - High CPU utilization (3-period evaluation)
    - Eviction monitoring
    - Replication bytes tracking
    - CPU credits monitoring for burstable instances
  - All alarms configurable via:
    - Enable/disable flags
    - Custom thresholds
    - SNS notifications

- **Security**:
  - Dedicated security group for Redis access
  - Inbound access limited to specified ASG
  - No explicit egress rules (follows AWS best practices)
  - Resource tagging for security compliance

---

## **File Structure**

The module consists of several Terraform files, each with a specific responsibility to maintain clean code organization and separation of concerns:

| **File**              | **Description**                                                                 |
|-----------------------|---------------------------------------------------------------------------------|
| `main.tf`             | Creates the ElastiCache subnet group, replication group, and parameter group    |
| `security_group.tf`   | Defines the security group for Redis and manages network access                 |
| `metrics.tf`          | Configures CloudWatch alarms for monitoring Redis performance                   |
| `variables.tf`        | Declares input variables for the module                                         |
| `outputs.tf`          | Exposes key outputs for integration with other modules                          |

---

## **Input Variables**

| **Name**                               | **Type**       | **Description**                                                         | **Default/Required**       |
|----------------------------------------|----------------|-------------------------------------------------------------------------|----------------------------|
| `name_prefix`                          | `string`       | Prefix for resource names                                               | **Required**               |
| `environment`                          | `string`       | Environment name (dev/stage/prod)                                       | **Required**               |
| `vpc_id`                               | `string`       | VPC ID for deployment                                                   | **Required**               |
| `private_subnet_ids`                   | `list(string)` | List of private subnet IDs                                              | **Required**               |
| `asg_security_group_id`                | `string`       | Security Group ID for ASG access                                        | **Required**               |
| `redis_version`                        | `string`       | Redis version (e.g., '7.1')                                             | **Required**               |
| `node_type`                            | `string`       | Node type (e.g., 'cache.t3.micro')                                      | **Required**               |
| `replicas_per_node_group`              | `number`       | Number of replicas per shard                                            | **Required**               |
| `num_node_groups`                      | `number`       | Number of shards                                                        | **Required**               |
| `enable_failover`                      | `bool`         | Enable automatic failover                                               | `false`                    |
| `redis_port`                           | `number`       | Redis port number                                                       | `6379`                     |
| `snapshot_retention_limit`             | `number`       | Days to retain snapshots                                                | **Required**               |
| `snapshot_window`                      | `string`       | Backup window (HH:MM-HH:MM)                                             | `"03:00-04:00"`            |
| `redis_cpu_threshold`                  | `number`       | CPU utilization threshold (%)                                           | **Required**               |
| `redis_memory_threshold`               | `number`       | Memory threshold (bytes)                                                | **Required**               |
| `redis_evictions_threshold`            | `number`       | Evictions threshold                                                     | `1`                        |
| `redis_cpu_credits_threshold`          | `number`       | CPU credits threshold                                                   | `5`                        |
| `redis_replication_bytes_threshold`    | `number`       | Replication bytes threshold                                             | `50000000`                 |
| `sns_topic_arn`                        | `string`       | SNS topic ARN for alarms                                                | **Required**               |
| `kms_key_arn`                          | `string`       | KMS key ARN for encryption                                              | **Required**               |
| `enable_redis_low_memory_alarm`        | `bool`         | Enable memory alarm                                                     | `false`                    |
| `enable_redis_high_cpu_alarm`          | `bool`         | Enable CPU alarm                                                        | `false`                    |
| `enable_redis_evictions_alarm`         | `bool`         | Enable evictions alarm                                                  | `false`                    |
| `enable_redis_replication_bytes_alarm` | `bool`         | Enable replication bytes alarm                                          | `false`                    |
| `enable_redis_low_cpu_credits_alarm`   | `bool`         | Enable CPU credits alarm                                                | `false`                    |

**Notes**:
- The `kms_key_arn` must be provided by the KMS module for encryption at rest
- `replication_bytes` alarms are only applicable when replicas are enabled

---

## **Outputs**

| **Name**                    | **Description**                                       |
|-----------------------------|-------------------------------------------------------|
| `redis_port`                | The port number for Redis connections                 |
| `redis_endpoint`            | The primary endpoint for connecting to Redis          |
| `redis_reader_endpoint`     | The reader endpoint for read replicas                 |
| `redis_security_group_id`   | The ID of the security group created for Redis        |
| `redis_replication_group_id`| The ID of the Redis replication group                 |
| `redis_arn`                 | The ARN of the Redis replication group                |
| `failover_status`           | Indicates if automatic failover is enabled            |

**Notes**:
- The `redis_endpoint` is used for write operations
- The `redis_reader_endpoint` is available when replicas are configured
- The `redis_arn` is useful for IAM policies and permissions
- The `failover_status` indicates if automatic failover is enabled (requires replicas)

---

## **Notes**

### Resource Naming
- Use consistent naming with 'name_prefix' across all resources
- Environment validation ensures deployment in correct context

### Network Design
- Requires private subnets for enhanced security
- Security group integration with ASG for controlled access

### Redis Configuration
- Supports Redis 7.x with version validation
- Flexible cluster architecture with configurable replicas and shards
- Automatic failover requires at least one replica

### Monitoring Strategy
- Comprehensive CloudWatch alarms for performance metrics
- Configurable thresholds for different environments
- CPU and memory monitoring with validated thresholds
- Special handling for burstable instances (CPU credits)

### Backup Management
- Configurable snapshot retention and timing
- Validated time window format for consistent scheduling

### Security Measures
- Mandatory KMS encryption for data at rest
- Integration with existing security groups
- SNS notifications for operational alerts

---

## **Future Improvements**

1. **Enhanced Monitoring**:
   - Integration with AWS Lambda for automated incident response
   - Additional CloudWatch metrics for network performance
   - Custom metric filters for log analysis

2. **Security Enhancements**:
   - Support for IAM authentication
   - Integration with AWS Secrets Manager for credentials
   - Enhanced network security controls

3. **Operational Features**:
   - Automated parameter group optimization
   - Support for Redis Cluster Mode for larger deployments
   - Automated backup verification

4. **Cost Optimization**:
   - Auto-scaling capabilities based on metrics
   - Resource scheduling for non-production environments
   - Cost allocation tag management

---

## **Usage Example**

```hcl
module "elasticache" {
  source = "./modules/elasticache"

  # Resource naming and environment
  name_prefix = "dev"
  environment = "dev"

  # Network configuration
  vpc_id                = "vpc-0123456789abcdef0"
  private_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  asg_security_group_id = "sg-0123456789abcdef0"

  # Redis core configuration
  redis_version = "7.1"
  node_type     = "cache.t2.micro"
  redis_port    = 6379

  # Cluster architecture
  replicas_per_node_group = 1
  num_node_groups         = 2
  enable_failover        = true

  # Backup configuration
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-04:00"

  # Monitoring thresholds
  redis_cpu_threshold              = 80  # 80% CPU utilization
  redis_memory_threshold           = 104857600  # 100MB free memory
  redis_evictions_threshold        = 1   # Alert on any eviction
  redis_cpu_credits_threshold      = 5   # For t2/t3 instances
  redis_replication_bytes_threshold = 50000000  # 50MB

  # Alarm configuration
  enable_redis_low_memory_alarm        = true
  enable_redis_high_cpu_alarm          = true
  enable_redis_evictions_alarm         = true
  enable_redis_replication_bytes_alarm = true
  enable_redis_low_cpu_credits_alarm   = true

  # Security configuration
  sns_topic_arn = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  kms_key_arn   = "arn:aws:kms:eu-west-1:123456789012:key/example"
}

# Example of accessing outputs
output "redis_connection_info" {
  value = {
    endpoint        = module.elasticache.redis_endpoint
    reader_endpoint = module.elasticache.redis_reader_endpoint
    port           = module.elasticache.redis_port
    arn            = module.elasticache.redis_arn
  }
}
```

The example above demonstrates:
- Setting up a Redis 7.1 cluster with one replica
- Enabling automatic failover for high availability
- Configuring comprehensive monitoring with CloudWatch alarms
- Implementing encryption using KMS
- Setting up backup with 7-day retention
- Accessing the module's outputs for further use

## **Authors**

This module was crafted following Terraform best practices, focusing on security, scalability, and maintainability. Contributions and feedback are welcome!

---

## **Useful Resources**

- [Amazon ElastiCache Documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/WhatIs.html)
- [AWS CloudWatch Monitoring for ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheMetrics.html)
- [AWS KMS Encryption](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
- [ElastiCache Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/BestPractices.html)

---