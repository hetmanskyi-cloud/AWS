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
  - Configures an RDS instance with options for Multi-AZ deployment for high availability.
  - Supports multiple database engines (e.g., MySQL, PostgreSQL).
  - Enables encryption at rest using AWS KMS.
  - Configurable automated backups and snapshot retention.
- **Read Replicas**:
  - Optional read replicas for improved read performance and fault tolerance.
- **Enhanced Monitoring**:
  - Provides detailed monitoring metrics by enabling Enhanced Monitoring with a dedicated IAM role.
  - Monitoring is conditionally created based on the `enable_rds_monitoring` variable.
- **CloudWatch Alarms**:
  - Monitors critical metrics such as:
    - **High CPU utilization**.
    - **Low free storage space**.
    - **High database connections**.
- **Security Group**:
  - Manages access control by allowing database connections only from ASG instances or Security Groups.
  - Security Group rules:
  - Ingress: Allows inbound traffic only from ASG Security Groups.
  - Egress: Limits outbound traffic to:
    - Internal communication within the VPC.
    - HTTPS traffic to S3 and CloudWatch Logs for backups and monitoring.
- **CloudWatch Logs**:
  - Exports audit, error, general, and slowquery logs to CloudWatch for enhanced observability.

---

## Files Structure

| **File**               | **Description**                                                               |
|------------------------|-------------------------------------------------------------------------------|
| `main.tf`              | Creates the primary RDS instance, subnet group, and optional read replicas.   |
| `security_group.tf`    | Configures the Security Group to manage RDS access control.                   |
| `metrics.tf`           | Defines CloudWatch Alarms for RDS performance monitoring.                     |
| `iam.tf`               | Configures IAM roles and policies for RDS Enhanced Monitoring.                |
| `variables.tf`         | Declares input variables for the module.                                      |
| `outputs.tf`           | Exposes key outputs for integration with other modules.                       |

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

---

## Outputs

| **Name**                        | **Description**                                       |
|---------------------------------|-------------------------------------------------------|
| `db_name`                       | The name of the RDS database.                         |
| `db_username`                   | The master username for the RDS database.             |
| `db_port`                       | The port number for database connections.             |
| `db_host`                       | The address of the RDS instance for connections.      |
| `db_endpoint`                   | The full endpoint of the RDS instance.                |
| `rds_security_group_id`         | The ID of the security group for RDS.                 |
| `rds_monitoring_role_arn`       | The ARN of the IAM role for RDS Enhanced Monitoring.  |
| `rds_read_replicas_ids`         | List of identifiers for the RDS read replicas.        |
| `rds_db_instance_id`            | Identifier of the primary RDS database instance.      |

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
  multi_az                = false
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
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}
```

---

## Notes

1. **Security**:
   - Encryption at rest and in transit is enabled by default.
   - Access to RDS is restricted via Security Groups.

2. **High Availability**:
   - Multi-AZ deployment and optional read replicas ensure fault tolerance.

3. **Flexibility**:
   - All key configurations, including backups, monitoring thresholds, and encryption, are customizable via input variables.

4. **Enhanced Monitoring**:
   - Monitoring metrics are conditionally created based on the `enable_rds_monitoring` variable.
   - Requires an IAM role with the `AmazonRDSEnhancedMonitoringRole` policy.
   - Enhanced Monitoring supports custom IAM policies for stricter permissions instead of the default `AmazonRDSEnhancedMonitoringRole`.

5. **AWS Secrets Manager Integration**:
   - For production environments, consider using AWS Secrets Manager to securely manage database credentials.

6. For production environments, consider using `aws_ip_ranges` to restrict egress rules to specific AWS services like S3 and CloudWatch Logs.

7. Input variables include validations (e.g., environment, instance class) to prevent configuration errors.

8. Enhanced Monitoring can use a custom IAM policy for improved security in production environments.

---

## Future Improvements

1. **Automated Read Replica Scaling**:
   - Implement automatic scaling for read replicas based on workload demands.

2. **Dynamic CloudWatch Alarms**:
   - Enable conditional CloudWatch Alarms with dynamic thresholds to adapt to workload patterns.

3. **AWS Secrets Manager Integration**:
   - Securely manage database credentials using AWS Secrets Manager.
   - Implement automatic password rotation and secure secret storage for RDS.

4. **Dedicated KMS Key for RDS**:
   - Use a separate KMS key for RDS encryption to enhance security and control access.

5. **Enable High Availability**:
   - Set `multi_az = true` in production environments to ensure high availability and fault tolerance across Availability Zones.

6. **Centralized Backup Management**:
   - Integrate with AWS Backup for centralized backup management, retention policies, and compliance.

7. **Advanced Monitoring and Alerting**:
   - Configure CloudWatch Alarms for all critical RDS metrics, including CPU, memory, storage, and connections.
   - Integrate CloudWatch Alarms with notification systems like Slack or PagerDuty for real-time alerts.

8. **Restrict Egress Rules with aws_ip_ranges**:
   - Limit egress rules for S3 and CloudWatch Logs to specific AWS service IP ranges for improved security.

---

## Authors

This module was crafted following Terraform best practices, with a focus on security, scalability, and observability. Contributions and feedback are welcome!

---

## Useful Resources

- [Amazon RDS Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html)
- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)