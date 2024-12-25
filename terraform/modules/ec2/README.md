# EC2 Module for Terraform

This module creates and manages EC2 instances and associated resources in AWS. It includes support for Auto Scaling Groups (ASG), monitoring, logging, and security configurations. Designed for environments like dev, stage, and prod, it adheres to best practices for scalability, performance, and security.

---

### Prerequisites

- **AWS Provider Configuration**:
The region and other parameters of the `aws` provider are specified in the `providers.tf` file of the root block.

An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Auto Scaling Group (ASG)**:
  - Automatically scales EC2 instances based on workload.
  - Disabled in the dev environment for simplicity.
- **Golden Image Management**:
  - EC2 instance for preparing golden images (enabled in dev by default).
  - Automation support for periodic updates in stage/prod.
- **CloudWatch Monitoring**:
  - Alarms monitor both individual instance (e.g., instance_image) and Auto Scaling Group (ASG) instances in stage/prod environments.
  - Notifications via SNS in stage and prod environments. They help ensure prompt responses to issues.
- **Security**:
  - Configurable Security Group for SSH, HTTP, and HTTPS traffic.
  - SSH access is restricted to specific IPs in prod.
  - SSM support for secure, passwordless instance management.
- **S3 Integration**:
  - Supports dynamic fetching of AMI metadata from S3.
  - Deployment scripts stored and fetched from S3 in stage/prod.
- **Tagging and Metadata**:
  - Consistent tagging for all instances to simplify identification and organization.
  - Enforces IMDSv2 for enhanced instance metadata security.

---

## Files Structure

| **File**                | **Description**                                                                          |
|-------------------------|------------------------------------------------------------------------------------------|
| `main.tf`               | Defines the ASG, scaling policies, and dynamic configurations for stage/prod.            |
| `iam.tf`                | Configures IAM roles and policies for EC2 instances.                                     |
| `instance_image.tf`     | Manages the EC2 instance used for creating golden images.                                |
| `launch_template_asg.tf`| Creates a launch template for ASG with configurations fetched dynamically from S3.       |
| `metrics.tf`            | Defines CloudWatch alarms for scaling and monitoring.                                    |
| `security_group.tf`     | Configures the Security Group for EC2 instances.                                         |
| `outputs.tf`            | Exposes key outputs for integration with other modules.                                  |
| `variables.tf`          | Declares input variables for the module.                                                 |

---

## Input Variables

| **Name**                     | **Type**       | **Description**                                                                        | **Default/Required**  |
|------------------------------|----------------|----------------------------------------------------------------------------------------|-----------------------|
| `environment`                | `string`       | Environment for the resources (e.g., dev, stage, prod).                                | Required              |
| `name_prefix`                | `string`       | Prefix for naming resources.                                                           | Required              |
| `ami_id`                     | `string`       | Amazon Machine Image (AMI) ID for EC2 instances.                                       | Required              |
| `instance_type`              | `string`       | Instance type (e.g., t2.micro).                                                        | Required              |
| `ssh_key_name`               | `string`       | Name of the SSH key for accessing EC2 instances.                                       | Optional              |
| `autoscaling_min`            | `number`       | Minimum number of instances in the Auto Scaling Group.                                 | Required              |
| `autoscaling_max`            | `number`       | Maximum number of instances in the Auto Scaling Group.                                 | Required              |
| `scale_out_cpu_threshold`    | `number`       | CPU utilization threshold for scaling out.                                             | Required              |
| `scale_in_cpu_threshold`     | `number`       | CPU utilization threshold for scaling in.                                              | Required              |
| `network_in_threshold`       | `number`       | Threshold for high incoming network traffic.                                           | Required              |
| `network_out_threshold`      | `number`       | Threshold for high outgoing network traffic.                                           | Required              |
| `volume_size`                | `number`       | Size of the root EBS volume for EC2 instances in GiB.                                  | Required              |
| `volume_type`                | `string`       | Type of the root EBS volume (e.g., gp2).                                               | Required              |
| `public_subnet_ids`          | `list(string)` | List of public subnet IDs for deploying instances.                                     | Required              |
| `vpc_id`                     | `string`       | VPC ID where EC2 instances are deployed.                                               | Required              |
| `target_group_arn`           | `string`       | ARN of the ALB target group for routing traffic.                                       | Required              |
| `sns_topic_arn`              | `string`       | ARN of the SNS Topic for CloudWatch alarms.                                            | Required              |
| `ami_bucket_name`            | `string`       | Name of the S3 bucket containing AMI metadata.                                         | Required              |
| `scripts_bucket_name`        | `string`       | Name of the S3 bucket containing deployment scripts.                                   | Required              |
| `ssh_allowed_ips`            | `list(string)` | List of IP ranges allowed to access SSH in prod.                                       | Optional              |

---

## Outputs

| **Name**               | **Description**                                  |
|------------------------|--------------------------------------------------|
| `ec2_asg_id`           | ID of the Auto Scaling Group.                    |
| `launch_template_id`   | ID of the EC2 Launch Template.                   |
| `instance_public_ips`  | Public IPs of instances (if assigned).           |
| `instance_private_ips` | Private IPs of instances.                        |
| `instance_ids`         | IDs of instances in the Auto Scaling Group.      |
| `ec2_security_group_id`| Security Group ID for EC2 instances.             |

---

## Usage Example

```hcl
module "ec2" {
  source                  = "./modules/ec2"
  environment             = "dev"
  name_prefix             = "dev"
  ami_id                  = "ami-0123456789abcdef0"
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
  target_group_arn        = module.alb.wordpress_tg_arn
  sns_topic_arn           = "arn:aws:sns:eu-west-1:123456789012:cloudwatch-alarms"
  ami_bucket_name         = "my-ami-bucket"
  scripts_bucket_name     = "my-scripts-bucket"
  ssh_allowed_ips         = ["203.0.113.0/24"]
}

output "ec2_asg_id" {
  value = module.ec2.ec2_asg_id
}

---

## Security Best Practices

1. **SSH Access**:
   - Restrict SSH in prod using `ssh_allowed_ips`.
   - Use Systems Manager (SSM) for secure management without persistent SSH access.
2. **Golden Images**:
   - Regularly update the AMI and verify deployment scripts stored in the `scripts` S3 bucket.
   - Check the accessibility and validity of S3 buckets (ami_bucket_name, scripts_bucket_name) before deployment.
3. **Scaling Policies**:
   - Monitor CPU utilization thresholds to optimize scaling and resource usage.
4. **CloudWatch Alarms**:
   - Use alarms in stage/prod for proactive issue detection.

---

### Notes

- ASG is disabled in dev to simplify resource usage.
- The instance_image configuration is used in all environments for generating golden images or debugging.
- Alarms dynamically adjust based on the environment, ensuring relevant monitoring and notifications.
- Golden image preparation is automated in dev; periodic updates are recommended for stage/prod.

---

### Future Improvements

1. Add support for instance lifecycle hooks (e.g., before terminate, after launch).
2. Automate AMI updates using EventBridge to streamline golden image lifecycle.
3. Enhance monitoring by integrating additional metrics like disk usage or memory utilization.

---

### Authors

This module is built following Terraform best practices to prioritize scalability, security, and maintainability. Contributions are welcome to enhance its functionality!

---

### Useful Resources

- [Amazon EC2 Documentation](https://docs.aws.amazon.com/ec2/index.html)
- [Terraform EC2 Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2/instance/latest)
- [CloudWatch Metrics for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring_ec2.html)

---