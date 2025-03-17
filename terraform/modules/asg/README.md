# Terraform ASG Module

This Terraform module creates and manages Auto Scaling Groups (ASG) and related resources on AWS. It's suitable for dev, stage, and prod environments, ensuring best practices for scalability, security, and performance.

---

## Prerequisites

- **AWS Provider Configuration**:
  The AWS region and other provider settings should be configured in the `providers.tf` file in your root module.  

---

## Features

- **Auto Scaling Group (ASG)**:
  - Automatic scaling based on workload with configurable thresholds.
  - Target tracking scaling policy for maintaining optimal CPU utilization.
  - Customizable termination policies for instance lifecycle management.

- **Launch Template**:
  - Configurable instance type, AMI, and EBS volume settings.
  - User data script for WordPress deployment with dynamic configuration.
  - Support for both local and S3-based deployment scripts.
  - Health check integration with ALB for application-level availability.

- **CloudWatch Monitoring**:
  - CloudWatch Alarms for ASG instances and individual instances.
  - SNS notifications for proactive alerts.
  - Detailed monitoring for better visibility.

- **Security**:
  - Configurable Security Groups (HTTP/HTTPS, SSH).
  - Systems Manager (SSM) support for secure instance management.
  - Conditional IAM policies with least privilege access.
  - IMDSv2 enforcement for enhanced metadata security.

- **S3 Integration**:
  - Optional retrieval of deployment scripts from S3.
  - Conditional WordPress media bucket access.
  - KMS encryption support for S3 objects and EBS volumes.

- **AWS Service Integration**:
  - Support for both public and private (VPC Endpoints) AWS service access.
  - Seamless integration with ALB for traffic routing.
  - Redis integration for WordPress caching.

- **Secrets Management**:
  - AWS Secrets Manager integration for secure credential storage.
  - IAM permissions for accessing WordPress credentials.

---

## Module Files Structure

| **File**             | **Description**                                             |
|----------------------|-------------------------------------------------------------|
| `main.tf`            | ASG, scaling policies, and dynamic configurations.          |
| `launch_template.tf` | ASG launch template with WordPress deployment configuration.|
| `iam.tf`             | IAM roles and conditional policies for S3, KMS, and SSM.    |
| `security_group.tf`  | Security Group rules for ASG instances with dynamic rules.  |
| `outputs.tf`         | Exposed outputs for integration and management.             |
| `variables.tf`       | Module input variables and configuration options.           |

---

## Input Variables

| **Variable**                     | **Type**      | **Description**                                                         | **Default / Required** |
|----------------------------------|---------------|-------------------------------------------------------------------------|------------------------|
| `environment`                    | `string`      | Environment (dev, stage, prod).                                         | Required               |
| `name_prefix`                    | `string`      | Prefix for resource naming.                                             | Required               |
| `instance_type`                  | `string`      | EC2 instance type (e.g., t2.micro).                                     | Required               |
| `ami_id`                         | `string`      | AMI ID for ASG instances.                                               | Required               |
| `autoscaling_min`                | `number`      | Minimum instances in ASG.                                               | Required               |
| `autoscaling_max`                | `number`      | Maximum instances in ASG.                                               | Required               |
| `desired_capacity`               | `number`      | Desired number of instances in ASG.                                     | `null` (dynamic)       |
| `scale_out_cpu_threshold`        | `number`      | CPU threshold (%) to scale out.                                         | Required               |
| `scale_in_cpu_threshold`         | `number`      | CPU threshold (%) to scale in.                                          | Required               |
| `volume_size`                    | `number`      | EBS volume size (GiB).                                                  | Required               |
| `volume_type`                    | `string`      | EBS volume type (gp2, gp3, etc.).                                       | Required               |
| `public_subnet_ids`              | `list(string)`| Public subnet IDs for ASG instances.                                    | Required               |
| `vpc_id`                         | `string`      | VPC ID for ASG resources.                                               | Required               |
| `wordpress_tg_arn`               | `string`      | ALB Target Group ARN for routing traffic.                               | Required               |
| `sns_topic_arn`                  | `string`      | SNS topic ARN for alarms.                                               | Required               |
| `enable_scaling_policies`        | `bool`        | Enable/disable scaling policies.                                        | `true`                 |
| `enable_https_listener`          | `bool`        | Enable HTTPS listener.                                                  | Required               |
| `enable_ebs_encryption`          | `bool`        | Enable EBS encryption.                                                  | `false`                |
| `ssh_key_name`                   | `string`      | SSH key pair name (optional).                                           | Required               |
| `enable_asg_ssh_access`          | `bool`        | Enable SSH access to ASG instances.                                     | `false`                |
| `ssh_allowed_cidr`               | `list(string)`| Allowed CIDR blocks for SSH.                                            | `["0.0.0.0/0"]`        |
| `default_region_buckets`         | `map(object)` | Configuration for S3 buckets in default region.                         | `{}`                   |
| `replication_region_buckets`     | `map(object)` | Configuration for S3 buckets in replication region.                     | `{}`                   |
| `wordpress_media_bucket_arn`     | `string`      | ARN of WordPress media S3 bucket.                                       | `""`                   |
| `scripts_bucket_arn`             | `string`      | ARN of scripts S3 bucket.                                               | `""`                   |
| `scripts_bucket_name`            | `string`      | Name of scripts S3 bucket.                                              | `""`                   |
| `enable_s3_script`               | `bool`        | Fetch WordPress deployment script from S3.                              | `false`                |
| `db_host`                        | `string`      | RDS database host for WordPress.                                        | Required               |
| `db_name`                        | `string`      | WordPress database name.                                                | Required               |
| `db_username`                    | `string`      | WordPress database username.                                            | Required               |
| `db_password`                    | `string`      | WordPress database password.                                            | Required (sensitive)   |
| `wp_admin_user`                  | `string`      | WordPress admin username.                                               | `"admin"`              |
| `wp_admin_password`              | `string`      | WordPress admin password.                                               | Required (sensitive)   |
| `wp_admin_email`                 | `string`      | WordPress admin email.                                                  | `"admin@example.com"`  |
| `php_version`                    | `string`      | PHP version for WordPress.                                              | Required               |
| `redis_endpoint`                 | `string`      | Redis endpoint for caching.                                             | Required               |
| `redis_port`                     | `number`      | Redis port for caching.                                                 | Required               |
| `wordpress_secret_name`          | `string`      | Secrets Manager secret name for WordPress credentials.                  | Required               |
| `healthcheck_version`            | `string`      | Version of healthcheck file to use.                                     | `"1.0"`                |
| `enable_interface_endpoints`     | `bool`        | Enable/disable Interface VPC Endpoints.                                 | `false`                |
| `vpc_endpoint_security_group_id` | `string`      | Security Group ID for VPC Endpoints.                                    | Required               |

---

## Outputs

| **Output**                       | **Description**                                         |
|----------------------------------|---------------------------------------------------------|
| `asg_id`                         | ASG ID for referencing.                                 |
| `asg_name`                       | ASG name for referencing.                               |
| `launch_template_id`             | Launch Template ID used by ASG.                         |
| `launch_template_latest_version` | Latest version of the Launch Template.                  |
| `instance_ids`                   | IDs of ASG instances (when data source enabled).        |
| `instance_public_ips`            | Public IPs of ASG instances (when data source enabled). |
| `instance_private_ips`           | Private IPs of ASG instances (when data source enabled).|
| `asg_security_group_id`          | Security Group ID associated with ASG instances.        |
| `instance_role_id`               | IAM role ID attached to ASG instances.                  |
| `instance_profile_arn`           | Instance profile ARN for ASG instances.                 |
| `scale_out_policy_arn`           | ARN of the Scale-Out Policy (when enabled).             |
| `scale_in_policy_arn`            | ARN of the Scale-In Policy (when enabled).              |
| `rendered_user_data`             | Rendered user_data script (sensitive).                  |

---

## Usage Example

```hcl
module "asg" {
  source                  = "./modules/asg"
  
  # General Configuration
  aws_account_id          = "123456789012"
  aws_region              = "eu-west-1"
  environment             = "dev"
  name_prefix             = "dev"
  
  # Instance Configuration
  ami_id                  = "ami-03fd334507439f4d1"
  instance_type           = "t2.micro"
  ssh_key_name            = "my-ssh-key"
  enable_asg_ssh_access   = false
  
  # Auto Scaling Configuration
  autoscaling_min         = 1
  autoscaling_max         = 3
  desired_capacity        = 1
  enable_scaling_policies = true
  scale_out_cpu_threshold = 60
  scale_in_cpu_threshold  = 40
  
  # Storage Configuration
  volume_size             = 8
  volume_type             = "gp2"
  enable_ebs_encryption   = false
  kms_key_arn             = "arn:aws:kms:eu-west-1:123456789012:key/abcd1234-a123-456a-a12b-a123b4cd56ef"
  
  # Network Configuration
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  alb_security_group_id   = module.alb.alb_security_group_id
  wordpress_tg_arn        = module.alb.wordpress_tg_arn
  enable_https_listener   = true
  
  # Database Configuration
  db_host                 = module.rds.db_endpoint
  db_endpoint             = module.rds.db_endpoint
  db_port                 = 3306
  db_name                 = "wordpress"
  db_username             = "wordpress"
  db_password             = "StrongPassword123!"
  rds_security_group_id   = module.rds.rds_security_group_id
  
  # WordPress Configuration
  wp_title                = "My WordPress Site"
  wp_admin_user           = "admin"
  wp_admin_password       = "AdminPassword123!"
  wp_admin_email          = "admin@example.com"
  php_version             = "8.1"
  php_fpm_service         = "php8.1-fpm"
  alb_dns_name            = module.alb.alb_dns_name
  wordpress_secret_name   = "wordpress/credentials"
  
  # Redis Configuration
  redis_endpoint          = module.elasticache.redis_endpoint
  redis_port              = 6379
  redis_security_group_id = module.elasticache.redis_security_group_id
  
  # S3 Configuration
  default_region_buckets  = {
    wordpress_media = {
      enabled    = true
      versioning = true
      logging    = true
    },
    scripts = {
      enabled    = true
      versioning = false
      logging    = false
    }
  }
  wordpress_media_bucket_arn = module.s3.wordpress_media_bucket_arn
  wordpress_media_bucket_name = module.s3.wordpress_media_bucket_name
  scripts_bucket_arn         = module.s3.scripts_bucket_arn
  scripts_bucket_name        = module.s3.scripts_bucket_name
  enable_s3_script           = true
  
  # Interface Endpoints Configuration
  enable_interface_endpoints     = false
  vpc_endpoint_security_group_id = module.interface_endpoints.endpoint_security_group_id
  
  # Monitoring Configuration
  sns_topic_arn            = module.sns.topic_arn
  
  # Additional Configuration
  healthcheck_version      = "2.0"
  enable_data_source       = true
}
```

---

## Security Best Practices

- **SSH Access**: Restrict SSH access to known CIDR blocks in production or disable completely.
- **KMS Encryption**: Enable KMS encryption for sensitive data in S3 and EBS volumes.
- **Security Groups**: Regularly audit Security Group rules and limit access to necessary services.
- **SSM Management**: Use AWS Systems Manager for secure instance management instead of SSH.
- **IAM Policies**: Follow least privilege principle for IAM roles and policies.
- **Metadata Security**: IMDSv2 is enforced to prevent metadata service attacks.
- **VPC Endpoints**: Enable Interface Endpoints when instances are in private subnets without internet access.

---

## Conditional Resource Creation

The module uses conditional resource creation for several components:

- **SSH Access**: Created only when `enable_asg_ssh_access = true`.
- **Scaling Policies**: Created only when `enable_scaling_policies = true`.
- **S3 Access**: IAM policies created only when relevant buckets are enabled.
- **HTTPS Listener**: Security group rules created only when `enable_https_listener = true`.
- **VPC Endpoints Integration**: Outbound rules adjusted based on `enable_interface_endpoints`.
- **KMS Policies**: Created only when encryption features are enabled.

---

## WordPress Deployment

The module includes a comprehensive WordPress deployment strategy:

1. **Launch Template**: Configures instances with user data script for WordPress installation.
2. **Health Checks**: Integrates with ALB for application-level health monitoring.
3. **Configuration**: Supports both local and S3-based deployment scripts.
4. **Redis Caching**: Integrates with ElastiCache for improved performance.
5. **Database Connection**: Securely connects to RDS for WordPress database.
6. **Media Storage**: Optionally uses S3 for WordPress media files.

---

## Future Improvements

- Lifecycle hooks for graceful scaling.
- Blue-green deployment support.
- Spot instance integration for cost optimization.
- Enhanced monitoring (memory/disk).

---

## Authors

This module is developed following Terraform best practices. Contributions are welcome!

---

## Useful Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Terraform AWS EC2 Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws)
- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [CloudWatch Monitoring](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring_ec2.html)
- [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/)