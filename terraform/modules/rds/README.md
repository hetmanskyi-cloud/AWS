# RDS Module for Terraform

This module provisions and manages an RDS (Relational Database Service) instance in AWS, including Multi-AZ deployment, read replicas, Enhanced Monitoring, CloudWatch Alarms, and secure networking configurations.

---

### Prerequisites

- **AWS Provider Configuration**:
  The AWS region and other parameters for the `aws` provider are specified in the root configuration file.
  An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Primary RDS Instance**:
  - Configures an RDS instance with options for Multi-AZ deployment for high availability
  - Supports multiple database engines (e.g., MySQL, PostgreSQL)
  - Enables encryption at rest using AWS KMS
  - Configurable automated backups and snapshot retention
- **Read Replicas**:
  - Optional read replicas for improved read performance and fault tolerance
- **Enhanced Monitoring**:
  - Provides detailed monitoring metrics by enabling Enhanced Monitoring with a dedicated IAM role
  - Monitoring is conditionally created based on the `enable_rds_monitoring` variable
- **CloudWatch Alarms**:
  - Monitors critical metrics such as:
    - **High CPU utilization**
    - **Low free storage space**
    - **High database connections**
- **Security Group**:
  - Manages access control by allowing database connections only from ASG instances
  - Security Group rules:
    - Ingress: Allows inbound traffic only from ASG Security Groups
    - No explicit egress rules needed due to VPC Endpoints usage
- **VPC Endpoints**:
  - Uses Gateway Endpoints for S3 (backups) and CloudWatch Logs
  - Keeps all traffic within AWS network
  - Improves security by eliminating need for internet access
- **CloudWatch Logs**:
  - Test Environment Configuration:
    - Exports error logs for critical issues and crashes
    - Includes slowquery logs for performance optimization during development
  - Production Environment Recommendations:
    - Add general logs for comprehensive activity monitoring (connections, DDL operations)
    - Consider audit logs for security and compliance requirements
  - Configurable log retention period via `rds_log_retention_days` variable
  - Log encryption using KMS for enhanced security

---

## Files Structure

| **File**               | **Description**                                                               |
|------------------------|-------------------------------------------------------------------------------|
| `main.tf`              | Creates the primary RDS instance, subnet group, and optional read replicas    |
| `security_group.tf`    | Configures the Security Group to manage RDS access control                    |
| `metrics.tf`           | Defines CloudWatch Alarms for RDS performance monitoring                      |
| `iam.tf`               | Configures IAM roles and policies for RDS Enhanced Monitoring                 |
| `variables.tf`         | Declares input variables for the module                                       |
| `outputs.tf`           | Exposes key outputs for integration with other modules                        |

---

## Input Variables

| **Name**                             | **Type**       | **Description**                                                               | **Default/Required**  |
|--------------------------------------|----------------|-------------------------------------------------------------------------------|-----------------------|
| `aws_region`                         | `string`       | The AWS region where RDS resources will be created.                           | Required              |
| `aws_account_id`                     | `string`       | AWS account ID for permissions and policies.                                  | Required              |
| `name_prefix`                        | `string`       | Prefix for resource names.                                                    | Required              |
| `environment`                        | `string`       | Environment for the resources (e.g., dev, stage, prod).                       | Required              |
| `allocated_storage`                  | `number`       | Storage size in GB for the RDS instance.                                      | Required              |
| `instance_class`                     | `string`       | Instance class for RDS (e.g., db.t3.micro).                                   | Required              |
| `engine`                             | `string`       | Database engine for the RDS instance (e.g., 'mysql', 'postgres').             | Required              |
| `engine_version`                     | `string`       | Database engine version (e.g., '8.0' for MySQL).                              | Required              |
| `db_username`                        | `string`       | Master username for the RDS database.                                         | Required              |
| `db_password`                        | `string`       | Master password for the RDS database.                                         | Required              |
| `db_name`                            | `string`       | Initial database name.                                                        | Required              |
| `db_port`                            | `number`       | Database port (default: 3306).                                                | `3306`                |
| `multi_az`                           | `bool`         | Enable Multi-AZ deployment for high availability.                             | Required              |
| `backup_retention_period`            | `number`       | Number of days to retain automated backups.                                   | Required              |
| `backup_window`                      | `string`       | Preferred window for automated backups (e.g., '03:00-04:00').                 | Required              |
| `performance_insights_enabled`       | `bool`         | Enable or disable Performance Insights.                                       | Required              |
| `deletion_protection`                | `bool`         | Enable or disable deletion protection for RDS.                                | Required              |
| `vpc_id`                             | `string`       | The VPC ID where the RDS instance will be deployed.                           | Required              |
| `private_subnet_ids`                 | `list(string)` | List of private subnet IDs for RDS deployment.                                | Required              |
| `asg_security_group_id`              | `string`       | Security Group ID for ASG instances that connect to RDS.                      | Required              |
| `kms_key_arn`                        | `string`       | The ARN of the KMS key for encryption (used by RDS and other modules)         | Required              |
| `enable_rds_monitoring`              | `bool`         | Enable RDS Enhanced Monitoring.                                               | Required              |
| `rds_cpu_threshold_high`             | `number`       | Threshold for high CPU utilization.                                           | Required              |
| `rds_storage_threshold`              | `number`       | Threshold for low free storage space (in bytes).                              | Required              |
| `rds_connections_threshold`          | `number`       | Threshold for high number of database connections.                            | Required              |
| `sns_topic_arn`                      | `string`       | ARN of the SNS Topic for CloudWatch alarms.                                   | Required              |
| `read_replicas_count`                | `number`       | Number of read replicas for the RDS instance.                                 | Required              |
| `rds_log_retention_days`             | `number`       | Number of days to retain RDS logs in CloudWatch                               | Required              |

---

## Outputs

| **Name**                        | **Description**                                       |
|---------------------------------|-------------------------------------------------------|
| `db_name`                       | The name of the RDS database                          |
| `db_port`                       | The port number for database connections              |
| `db_host`                       | The address of the RDS instance for connections       |
| `db_endpoint`                   | The full endpoint of the RDS instance                 |
| `rds_security_group_id`         | The ID of the security group for RDS                  |
| `rds_monitoring_role_arn`       | The ARN of the IAM role for RDS Enhanced Monitoring   |
| `rds_read_replicas_ids`         | List of identifiers for the RDS read replicas         |
| `rds_read_replicas_endpoints`   | List of endpoints for the RDS read replicas           |
| `db_instance_identifier`        | Identifier of the primary RDS database instance       |
| `db_arn`                        | The ARN of the RDS instance                           |
| `db_status`                     | The current status of the RDS instance                |

---

## Best Practices

### Logging and Monitoring

1. **Log Management**:
   - Review and adjust log retention periods based on compliance requirements
   - Monitor CloudWatch costs, especially when enabling additional log types
   - Consider enabling general and audit logs in production for comprehensive monitoring

2. **Performance Monitoring**:
   - Use slowquery logs during development to identify and optimize problematic queries
   - Set up CloudWatch Alarms for critical metrics
   - Enable Enhanced Monitoring for detailed performance insights

3. **Security**:
   - Ensure KMS keys are properly managed for log encryption
   - Regularly review security group rules
   - Follow the principle of least privilege for IAM roles

---

## Usage Example

```hcl
module "rds" {
  source                  = "./modules/rds"
  name_prefix             = "dev"
  environment             = "dev"
  allocated_storage       = 20
  instance_class          = "db.t3.micro"
  engine                  = "mysql"
  engine_version          = "8.0"
  db_username             = "****"
  db_password             = "****"
  db_name                 = "****"
  multi_az                = false  # Defaults to false for test environments
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  performance_insights_enabled = false
  deletion_protection     = false
  vpc_id                  = "vpc-0123456789abcdef0"
  private_subnet_ids      = ["subnet-abcdef123", "subnet-123abcdef"]
  asg_security_group_id   = "sg-0123456789abcdef0"
  kms_key_arn             = "arn:aws:kms:eu-west-1:123456789012:key/example-key"
  enable_rds_monitoring   = false
  rds_cpu_threshold_high  = 80
  rds_storage_threshold   = 10000000000 # 10 GB
  rds_connections_threshold = 100
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  read_replicas_count     = 0
  rds_log_retention_days  = 30
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}
```

---

## Notes

1. **Security**:
   - Encryption at rest and in transit is enabled by default
   - Access to RDS is restricted via Security Groups
   - VPC Endpoints ensure traffic stays within AWS network
   - No direct internet access required for RDS operations

2. **High Availability**:
   - Multi-AZ deployment (optional) and read replicas ensure fault tolerance
   - Default to single-AZ for test environments

3. **Flexibility**:
   - All key configurations, including backups, monitoring thresholds, and encryption, are customizable via input variables

4. **Enhanced Monitoring**:
   - Monitoring metrics are conditionally created based on the `enable_rds_monitoring` variable
   - Requires an IAM role with the `AmazonRDSEnhancedMonitoringRole` policy
   - Enhanced Monitoring supports custom IAM policies for stricter permissions

5. **VPC Endpoints**:
   - Uses Gateway Endpoints for S3 (backups) and CloudWatch Logs
   - Eliminates need for NAT Gateway or internet access
   - Improves security and reduces data transfer costs

---

## Future Improvements

1. **Parameter Groups Management**:
   - Add support for custom parameter groups
   - Enable parameter group modifications through variables
   - Add validation for engine-specific parameters

2. **Backup Strategy Enhancement**:
   - Add support for cross-region backups
   - Implement automated snapshot copying to a DR region
   - Add option for S3 export of automated backups

3. **Security Enhancements**:
   - Add support for IAM authentication
   - Implement automated password rotation using Secrets Manager
   - Add option for SSL/TLS certificate management
   - Add support for custom KMS keys per environment

4. **Monitoring Improvements**:
   - Add Performance Insights dashboard configuration
   - Implement custom metric filters for slow query logs
   - Add support for automated log exports to S3
   - Create predefined CloudWatch dashboards

5. **Operational Efficiency**:
   - Add support for maintenance window configuration
   - Implement automated minor version upgrades
   - Add option for stop/start scheduling in non-prod
   - Add support for automated instance class recommendations

6. **Cost Optimization**:
   - Add support for Aurora Serverless v2 as an alternative
   - Implement storage autoscaling with configurable thresholds
   - Add option for automated storage optimization
   - Support for graviton instances in compatible regions

7. **Testing and Validation**:
   - Add example test configurations
   - Implement automated backup testing
   - Add connection testing module
   - Create validation for security group rules

8. **Documentation**:
   - Add architecture diagrams
   - Include cost estimation examples
   - Add performance tuning guidelines
   - Create troubleshooting guide

---

## Authors

This module was crafted following Terraform best practices, with a focus on security, scalability, and observability. Contributions and feedback are welcome!

---

## Useful Resources

- [Amazon RDS Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [RDS Security](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html)
- [RDS Monitoring](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Monitoring.html)
- [RDS Performance Insights](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
- [RDS Backup and Restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_CommonTasks.BackupRestore.html)
- [AWS CloudWatch for RDS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/rds-metricscollected.html)
- [RDS Parameter Groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html)
- [RDS Cost Optimization](https://aws.amazon.com/blogs/database/best-practices-for-amazon-rds-cost-optimization/)
- [Terraform RDS Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)