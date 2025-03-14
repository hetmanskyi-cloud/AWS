# Terraform ASG Module

This Terraform module creates and manages Auto Scaling Groups (ASG) and related resources on AWS. It's suitable for dev, stage, and prod environments, ensuring best practices for scalability, security, and performance.

---

## Prerequisites

- **AWS Provider Configuration**:

  The AWS region and other provider settings should be configured in the `providers.tf` file in your root module.  

---

## Features

- **Auto Scaling Group (ASG)**:
  - Automatic scaling based on workload.

- **CloudWatch Monitoring**:
  - CloudWatch Alarms for ASG instances and individual instances.
  - SNS notifications for proactive alerts.

- **Security**:
  - Configurable Security Groups (HTTP/HTTPS, SSH).
  - Systems Manager (SSM) support for secure instance management.
  - Conditional IAM policies with least privilege access.

- **S3 Integration**:
  - Optional retrieval of deployment scripts from S3.
  - Conditional WordPress media bucket access.

- **Tagging and Metadata**:
  - Consistent resource tagging.
  - IMDSv2 enforced for enhanced metadata security.

---

## File Structure

| **File**             | **Description**                                             |
|----------------------|-------------------------------------------------------------|
| `main.tf`            | ASG, scaling policies, and dynamic configurations.          |
| `iam.tf`             | IAM roles and conditional policies.                         |
| `launch_template.tf` | ASG launch template configuration.                          |
| `metrics.tf`         | CloudWatch alarms and metrics for monitoring.               |
| `security_group.tf`  | Security Group rules for ASG instances.                     |
| `outputs.tf`         | Exposed outputs for integration and management.             |
| `variables.tf`       | Module input variables and configuration options.           |

---

## Input Variables

| **Variable**                | **Type**       | **Description**                                                         | **Default / Required** |
|-----------------------------|----------------|-------------------------------------------------------------------------|------------------------|
| `environment`               | `string`       | Environment (dev, stage, prod).                                         | Required               |
| `name_prefix`               | `string`       | Prefix for resource naming.                                             | Required               |
| `instance_type`             | `string`       | EC2 instance type (e.g., t2.micro).                                     | Required               |
| `ami_id`                    | `string`       | AMI ID for ASG instances.                                               | Required               |
| `autoscaling_min`           | `number`       | Minimum instances in ASG.                                               | Required               |
| `autoscaling_max`           | `number`       | Maximum instances in ASG.                                               | Required               |
| `scale_out_cpu_threshold`   | `number`       | CPU threshold (%) to scale out.                                         | Required               |
| `scale_in_cpu_threshold`    | `number`       | CPU threshold (%) to scale in.                                          | Required               |
| `network_in_threshold`      | `number`       | Incoming network threshold (bytes).                                     | Required               |
| `network_out_threshold`     | `number`       | Outgoing network threshold (bytes).                                     | Required               |
| `volume_size`               | `number`       | EBS volume size (GiB).                                                  | Required               |
| `volume_type`               | `string`       | EBS volume type (gp2, gp3, etc.).                                       | Required               |
| `public_subnet_ids`         | `list(string)` | Public subnet IDs for ASG instances.                                    | Required               |
| `vpc_id`                    | `string`       | VPC ID for ASG resources.                                               | Required               |
| `wordpress_tg_arn`          | `string`       | ALB Target Group ARN for routing traffic.                               | Required               |
| `sns_topic_arn`             | `string`       | SNS topic ARN for alarms.                                               | Required               |
| `enable_scaling_policies`   | `bool`         | Enable/disable scaling policies.                                        | `true`                 |
| `enable_https_listener`     | `bool`         | Enable HTTPS listener.                                                  | Required               |
| `enable_ebs_encryption`     | `bool`         | Enable EBS encryption.                                                  | `false`                |
| `ssh_key_name`              | `string`       | SSH key pair name (optional).                                           | Required               |
| `enable_asg_ssh_access`     | `bool`         | Enable SSH access to ASG instances.                                     | `false`                |
| `ssh_allowed_cidr`          | `list(string)` | Allowed CIDR blocks for SSH.                                            | `0.0.0.0/0`            |
| `wordpress_media_bucket_arn`| `string`       | ARN of WordPress media S3 bucket.                                       | Optional               |
| `scripts_bucket_arn`        | `string`       | ARN of scripts S3 bucket.                                               | Optional               |

---

## Outputs

| **Output**                | **Description**                                    |
|---------------------------|----------------------------------------------------|
| `asg_id`                  | ASG ID for referencing.                            |
| `launch_template_id`      | Launch Template ID used by ASG.                    |
| `instance_ids`            | IDs of ASG instances.                              |
| `instance_public_ips`     | Public IPs of ASG instances (if assigned).         |
| `instance_private_ips`    | Private IPs of ASG instances.                      |
| `asg_security_group_id`   | Security Group ID associated with ASG instances.   |

---

## Usage Example

```hcl
module "asg" {
  source                  = "./modules/asg"
  environment             = "dev"
  name_prefix             = "dev"
  ami_id                  = "ami-03fd334507439f4d1"
  instance_type           = "t2.micro"
  ssh_key_name            = "my-ssh-key"
  autoscaling_min         = 1
  autoscaling_max         = 3
  scale_out_cpu_threshold = 60
  scale_in_cpu_threshold  = 40
  network_in_threshold    = 5000000
  network_out_threshold   = 5000000
  volume_size             = 8
  volume_type             = "gp2"
  public_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]
  vpc_id                  = "vpc-0123456789abcdef0"
  wordpress_tg_arn        = module.alb.wordpress_tg_arn
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  enable_https_listener   = true
}
```

---

## Security Best Practices

- Restrict SSH access to known CIDR blocks in production.
- Enable KMS encryption for sensitive data.
- Regularly audit Security Group rules.
- Use SSM for secure instance management.
- Implement proactive monitoring and alerts.

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