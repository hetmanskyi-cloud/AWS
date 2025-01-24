# ASG Module for Terraform

This module creates and manages ASG instances and associated resources in AWS. It includes support for Auto Scaling Groups (ASG), monitoring, logging, and security configurations. Designed for environments like dev, stage, and prod, it adheres to best practices for scalability, performance, and security.

---

## Prerequisites

- **AWS Provider Configuration**:
  The region and other parameters of the `aws` provider are specified in the `providers.tf` file of the root block.
  
  An example of the configuration can be found in the "Usage Example" section.

---

## Features

- **Auto Scaling Group (ASG):**
  - Automatically scales ASG instances based on workload.
- **CloudWatch Monitoring:**
  - Alarms monitor both individual instances and Auto Scaling Group (ASG) instances
  - Notifications via SNS, ensuring prompt responses to issues.
- **Security:**
  - Configurable Security Group for HTTP and HTTPS traffic.
  - SSM support for secure, passwordless instance management.
- **S3 Integration:**
  - Supports fetching deployment scripts from S3.
  - WordPress media is stored and fetched from S3 if the `wordpress_media_bucket` is enabled.
- **Tagging and Metadata:**
  - Consistent tagging for all instances to simplify identification and organization.
  - Enforces IMDSv2 for enhanced instance metadata security.

---

## File Structure

| **File**                 | **Description**                                                                    |
|--------------------------|------------------------------------------------------------------------------------|
| `main.tf`                | Defines the ASG, scaling policies, and dynamic configurations for stage/prod.      |
| `iam.tf`                 | Configures IAM roles and policies for ASG instances.                               |
| `launch_template.tf`     | Creates a launch template for ASG instances.                                       |
| `metrics.tf`             | Defines CloudWatch alarms for scaling and monitoring.                              |
| `security_group.tf`      | Configures the Security Group for ASG instances.                                   |
| `outputs.tf`             | Exposes key outputs for integration with other modules.                            |
| `variables.tf`           | Declares input variables for the module.                                           |

---

## Input Variables

| **Name**                     | **Type**       | **Description**                                                    | **Default/Required**  |
|------------------------------|----------------|--------------------------------------------------------------------|-----------------------|
| `environment`                | `string`       | Environment for the resources (e.g., dev, stage, prod).            | Required              |
| `name_prefix`                | `string`       | Prefix for naming resources.                                       | Required              |
| `instance_type`              | `string`       | Instance type (e.g., t2.micro).                                    | Required              |
| `autoscaling_min`            | `number`       | Minimum number of instances in the Auto Scaling Group.             | Required              |
| `autoscaling_max`            | `number`       | Maximum number of instances in the Auto Scaling Group.             | Required              |
| `scale_out_cpu_threshold`    | `number`       | CPU utilization threshold for scaling out.                         | Required              |
| `scale_in_cpu_threshold`     | `number`       | CPU utilization threshold for scaling in.                          | Required              |
| `network_in_threshold`       | `number`       | Threshold for high incoming network traffic.                       | Required              |
| `network_out_threshold`      | `number`       | Threshold for high outgoing network traffic.                       | Required              |
| `volume_size`                | `number`       | Size of the root EBS volume for ASG instances in GiB.              | Required              |
| `volume_type`                | `string`       | Type of the root EBS volume (e.g., gp2).                           | Required              |
| `public_subnet_ids`          | `list(string)` | List of public subnet IDs for deploying instances.                 | Required              |
| `vpc_id`                     | `string`       | VPC ID where EC2 instances are deployed.                           | Required              |
| `target_group_arn`           | `string`       | ARN of the ALB target group for routing traffic.                   | Required              |
| `sns_topic_arn`              | `string`       | ARN of the SNS Topic for CloudWatch alarms.                        | Required              |
| `wordpress_media_bucket_arn` | `string`       | ARN of the S3 bucket containing media files.                       | Optional              |
| `scripts_bucket_arn`         | `string`       | ARN of the S3 bucket containing deployment scripts.                | Required              |

---

## Outputs

| **Name**                   | **Description**                                  |
|----------------------------|--------------------------------------------------|
| `asg_id`                   | ID of the Auto Scaling Group.                    |
| `launch_template_id`       | ID of the ASG Launch Template.                   |
| `instance_public_ips`      | Public IPs of instances (if assigned).           |
| `instance_private_ips`     | Private IPs of instances.                        |
| `instance_ids`             | IDs of instances in the Auto Scaling Group.      |
| `asg_security_group_id`    | Security Group ID for ASG instances.             |

---

## Usage Example

```hcl
module "asg" {
  source                  = "./modules/asg"
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
  scripts_bucket_name     = "my-scripts-bucket"
}
```

---

## Security Best Practices

1. **SSH Access:**
   - Restrict SSH in prod using `ssh_allowed_cidr`.
   - Use Systems Manager (SSM) for secure management without persistent SSH access.
2. **Scaling Policies:**
   - Monitor CPU utilization thresholds to optimize scaling and resource usage.
3. **CloudWatch Alarms:**
   - Use alarms for proactive issue detection.

---

## Future Improvements

1. **Instance Lifecycle Hooks**  
   - Consider implementing lifecycle hooks to perform tasks before instances are launched or terminated (e.g., pre-warm configuration, graceful shutdown handling), ensuring better resource management and smooth transitions.

2. **Blue-Green Deployment Support**  
   - Evaluate the possibility of introducing blue-green deployment strategies for seamless application updates with minimal downtime, if required to improve deployment reliability.

3. **Spot Instance Integration**  
   - Assess the feasibility of adding support for mixed instance types and spot instances to optimize cost efficiency while maintaining high availability when applicable.

4. **Golden AMI Implementation**  
   - Explore the use of golden AMIs to standardize and streamline instance deployments, leveraging AWS Systems Manager and EventBridge for automated AMI updates and patch management.

5. **Enhanced Monitoring**  
   - Extend CloudWatch metrics coverage by adding memory and disk utilization insights for improved resource allocation and operational visibility.

6. **Logging Improvements**  
   - Consider enabling CloudWatch log aggregation and export to S3 for long-term storage, analysis, and compliance with organizational policies.

7. **Graceful Scale-In Policies**  
   - Ensure that scale-in policies effectively drain connections and gracefully terminate instances without causing disruptions to application availability by leveraging ALB health checks and deregistration delays.

---

## Authors

This module is built following Terraform best practices to prioritize scalability, security, and maintainability. Contributions are welcome to enhance its functionality!

---

## Useful Resources

- [Amazon EC2 Documentation](https://docs.aws.amazon.com/ec2/index.html)
- [Terraform EC2 Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2/instance/latest)
- [CloudWatch Metrics for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring_ec2.html)

---