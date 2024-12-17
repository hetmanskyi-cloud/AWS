# RDS Module for Terraform

This module provisions and manages an RDS (Relational Database Service) instance in AWS, including Multi-AZ deployment, read replicas, Enhanced Monitoring, CloudWatch Alarms, and secure networking configurations. It is designed to work across multiple environments (`dev`, `stage`, and `prod`) with optimized settings for each environment.

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
- **CloudWatch Alarms**:
  - Monitors critical metrics such as:
    - **High CPU utilization**.
    - **Low free storage space** (adjusted for dev environments).
    - **High database connections**.
- **Security Group**:
  - Manages access control by allowing database connections only from specific EC2 instances or Security Groups.
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
| `backup_window`                      | `string`       | Preferred window for automated backups (e.g., '02:00-03:00').                 | Required              |
| `performance_insights_enabled`       | `bool`         | Enable or disable Performance Insights.                                       | Required              |
| `deletion_protection`                | `bool`         | Enable or disable deletion protection for RDS.                                | Required              |
| `vpc_id`                             | `string`       | The VPC ID where the RDS instance will be deployed.                           | Required              |
| `private_subnet_ids`                 | `list(string)` | List of private subnet IDs for RDS deployment.                                | Required              |
| `ec2_security_group_id`              | `string`       | Security Group ID for EC2 instances that connect to RDS.                      | Required              |
| `kms_key_arn`                        | `string`       | The ARN of the KMS key for RDS encryption.                                    | Required              |
| `enable_monitoring`                  | `bool`         | Enable RDS Enhanced Monitoring.                                               | Required              |
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
  ec2_security_group_id   = "sg-0123456789abcdef0"
  kms_key_arn             = "arn:aws:kms:eu-west-1:123456789012:key/example-key"
  enable_monitoring       = false
  rds_cpu_threshold_high  = 80
  rds_storage_threshold   = 10000000000 # 10 GB
  rds_connections_threshold = 100
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  read_replicas_count     = 0
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

---

## Notes

1. Monitoring Strategy:

Minimal monitoring in dev to reduce noise and costs.

Full monitoring in stage and prod, including CPU utilization, storage, and connection thresholds.

2. Security:

Encryption at rest and in transit is enabled by default.

Access to RDS is restricted via Security Groups.

3. High Availability:

Multi-AZ deployment and optional read replicas ensure fault tolerance.

4. Flexibility:

All key configurations, including backups, monitoring thresholds, and encryption, are customizable via input variables.

---

## Future Improvements

Add support for automated scaling of read replicas.

Integrate with AWS Secrets Manager for secure management of database credentials.

Provide conditional CloudWatch Alarms based on dynamic thresholds.

---

## Authors

This module was crafted following Terraform best practices, with a focus on security, scalability, and observability. Contributions and feedback are welcome!

---

## Useful Resources

Amazon RDS Documentation

[AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/