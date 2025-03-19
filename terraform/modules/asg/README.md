# AWS Auto Scaling Group (ASG) Terraform Module

This Terraform module provisions a fully managed AWS Auto Scaling Group (ASG) with all supporting resources required to host a scalable WordPress application. It integrates seamlessly with the Application Load Balancer (ALB), RDS MySQL, ElastiCache Redis, and optionally uses S3 for media storage and deployment scripts.

---

## Module Purpose

- Automatically scale EC2 instances based on load.
- Deploy and configure WordPress with full infrastructure support.
- Integrate with ALB, RDS, Redis, S3, CloudWatch, IAM, and KMS.

---

## Prerequisites

- AWS provider configured in `providers.tf`.
- Valid AMI ID for the selected region.
- Existing VPC, subnets, and ALB.

---

## Architecture Diagram

```text
CloudWatch Alarms ──► SNS Topic ──► Auto Scaling Group (ASG)
                                       │
                   ┌───────────────────┴────────────────────┐
                   │                   │                     │
            Scale-Out Policy   Scale-In Policy   Target Tracking Policy
                   │                   │                     │
                   └──────────► Launch Template ◄────────────┘
                                       │
           ┌─────────────┬─────────────┼──────────────┬───────────────┐
           │             │             │              │               │
  User Data Script   Security Group   IAM Role   Metadata Options   Monitoring
           │             │             │              │               │
           └─────────────┴─────────────┴──────────────┴───────────────┘
                                       │
                                       ▼
                               EC2 Instances (WordPress)
                                       │
                    ┌──────────────────┴─────────────────┐
                    │                                    │
              RDS Database                   ElastiCache Redis
```

---

## Features

### Auto Scaling and Load Management
- Configurable min, max, and desired capacity.
- CPU target tracking and manual scaling policies.
- Health checks via ALB.
- Lifecycle management with `create_before_destroy`.

### Launch Template
- EC2 instance specifications (AMI, instance type, volumes).
- User data for automated WordPress deployment.
- Local or S3-based deployment script support.
- EBS encryption and metadata options with IMDSv2.

### Security
- Security Group with dynamic rules (SSH, ALB HTTP/HTTPS).
- Optional SSH access.
- IAM role and instance profile with:
  - S3 access (WordPress media, deployment scripts).
  - CloudWatch logs and monitoring.
  - SSM for management.
  - KMS decryption for encrypted resources.
- Enforced metadata security via IMDSv2.

### Monitoring and CloudWatch Alarms
- CPU-based scale-out and scale-in alarms.
- Status check alarms for instance health.
- Network In/Out traffic monitoring.
- SNS notifications for all alarms.
- Target Tracking Scaling (AWS-managed CloudWatch alarms) with default target of 50% CPU utilization.

### KMS and Encryption Support
- Optional EBS volume encryption.
- S3 encryption support with KMS.
- KMS permissions dynamically assigned.

### S3 Script Mode
- If `enable_s3_script` is `true`, fetches deployment script from S3.
- Fallback to local script if disabled.

### Metadata Security (IMDSv2)
- All EC2 instances enforce IMDSv2 to protect metadata.

### Secrets and Database
- Integration with AWS Secrets Manager.
- Secure connection to RDS.
- Redis caching support.

---

## Module Files Structure

| File                  | Description                                                   |
|-----------------------|---------------------------------------------------------------|
| `main.tf`             | ASG resource, scaling policies, lifecycle rules.              |
| `launch_template.tf`  | EC2 instance configuration and user data.                     |
| `iam.tf`              | IAM role, policies, instance profile.                         |
| `security_group.tf`   | ASG security group with conditional rules.                    |
| `metrics.tf`          | CloudWatch Alarms (CPU, status, network).                     |
| `outputs.tf`          | Outputs for integration and debugging.                        |
| `variables.tf`        | Module input variables.                                       |

---

## Inputs (Partial List)

| Variable                     | Type         | Description                                             | Default / Required |
|------------------------------|--------------|---------------------------------------------------------|--------------------|
| aws_account_id               | string       | AWS Account ID                                          | Required           |
| aws_region                   | string       | AWS Region                                              | Required           |
| environment                  | string       | dev, stage, prod                                        | Required           |
| name_prefix                  | string       | Resource name prefix                                    | Required           |
| instance_type                | string       | EC2 instance type                                       | Required           |
| ami_id                       | string       | AMI ID                                                  | Required           |
| ssh_key_name                 | string       | SSH Key Pair name                                       | Required           |
| autoscaling_min              | number       | Minimum instances                                       | Required           |
| autoscaling_max              | number       | Maximum instances                                       | Required           |
| desired_capacity             | number       | Desired capacity                                        | null / Optional    |
| scale_out_cpu_threshold      | number       | CPU % threshold to scale out                            | Required           |
| scale_in_cpu_threshold       | number       | CPU % threshold to scale in                             | Required           |
| volume_size                  | number       | EBS volume size (GiB)                                   | Required           |
| volume_type                  | string       | EBS volume type                                         | Required           |
| vpc_id                       | string       | VPC ID                                                  | Required           |
| public_subnet_ids            | list(string) | Subnets for ASG instances                               | Required           |
| wordpress_tg_arn             | string       | ALB Target Group ARN                                    | Required           |
| sns_topic_arn                | string       | SNS topic for alarms                                    | Required           |
| kms_key_arn                  | string       | KMS key ARN                                             | Required           |
| php_version                  | string       | PHP version                                             | Required           |
| php_fpm_service              | string       | PHP-FPM service name                                    | Required           |
| redis_endpoint               | string       | Redis endpoint                                          | Required           |
| redis_port                   | number       | Redis port                                              | Required           |
| wordpress_media_bucket_name  | string       | S3 bucket for WordPress media                           | ""                 |
| scripts_bucket_name          | string       | S3 bucket for deployment scripts                        | ""                 |
| healthcheck_version          | string       | Version of healthcheck (1.0 / 2.0)                      | "1.0"              |
| enable_interface_endpoints   | bool         | Use VPC Interface Endpoints                             | false              |
| enable_data_source           | bool         | Enable fetching ASG instance data                       | false              |

_(Full input table available in code)_

---

## Outputs

| Output                        | Description                                          |
|-------------------------------|------------------------------------------------------|
| asg_id                        | Auto Scaling Group ID                                |
| asg_name                      | Auto Scaling Group Name                              |
| launch_template_id            | Launch Template ID                                   |
| launch_template_latest_version| Latest version of Launch Template                    |
| instance_ids                  | ASG instance IDs (if enabled)                        |
| instance_public_ips           | Public IPs of ASG instances                          |
| instance_private_ips          | Private IPs of ASG instances                         |
| asg_security_group_id         | Security Group ID for ASG instances                  |
| instance_role_id              | IAM Role ID for instances                            |
| instance_profile_arn          | IAM Instance Profile ARN                             |
| scale_out_policy_arn          | Scale-Out Policy ARN                                 |
| scale_in_policy_arn           | Scale-In Policy ARN                                  |
| rendered_user_data (sensitive)| Rendered User Data script                            |

---

## Example Usage

```hcl
module "asg" {
  source = "./modules/asg"

  aws_account_id    = var.aws_account_id
  aws_region        = var.aws_region
  environment       = "dev"
  name_prefix       = "dev"
  instance_type     = "t2.micro"
  ami_id            = "ami-03fd334507439f4d1"
  ssh_key_name      = "my-ssh-key"

  autoscaling_min   = 1
  autoscaling_max   = 3
  desired_capacity  = 1

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  wordpress_tg_arn  = module.alb.wordpress_tg_arn
  sns_topic_arn     = module.sns.topic_arn

  # Optional
  kms_key_arn       = module.kms.kms_key_arn
  enable_s3_script  = true
  healthcheck_version = "2.0"
}
```

---

## Conditional Resource Creation

- SSH rules only if `enable_asg_ssh_access = true`
- Scaling policies if `enable_scaling_policies = true`
- CloudWatch Alarms (CPU, Network, Status) based on individual toggles.
- KMS and S3 policies created conditionally.
- IMDSv2 always enforced.
- Target Tracking is optional.

---

## Security Best Practices

- Disable SSH in production (use SSM).
- Enable KMS encryption for S3 and EBS.
- Use IMDSv2 exclusively.
- Monitor all alarms via SNS.
- Enable Interface Endpoints if deploying in private subnets.
- Limit Security Group CIDRs.

---

## Future Improvements

- Lifecycle hooks (graceful scaling).
- Blue/Green deployments.
- Spot Instances support.
- CloudWatch Anomaly Detection.
- AWS Security Hub integration.

---

## Troubleshooting and Common Issues

### 1. EC2 Instances Have No Internet Access
**Cause:** Missing or incorrect route to the Internet Gateway in public subnets.  
**Solution:**  
- Ensure the `vpc_zone_identifier` references public subnets.  
- Verify the route table includes `0.0.0.0/0 → igw` pointing to the Internet Gateway.

---

### 2. User Data Script Not Executed or WordPress Not Installed
**Cause:** Incorrect user data rendering, missing execution permissions, or failed S3 script fetch.  
**Solution:**  
- Check the `rendered_user_data` output for correctness.  
- Ensure the script is executable (`chmod +x`).  
- If using S3, validate bucket permissions and that `enable_s3_script = true` is configured properly.

---

### 3. Auto Scaling (Scale-Out/Scale-In) Not Triggering
**Cause:** Misconfigured CloudWatch thresholds, disabled scaling policies, or target tracking issues.  
**Solution:**  
- Adjust `scale_out_cpu_threshold` and `scale_in_cpu_threshold`.  
- Ensure `enable_scaling_policies = true`.  
- Check CloudWatch metrics and alarms are configured correctly.

---

### 4. Instances Marked Unhealthy by ALB
**Cause:** ALB health check path misconfigured or application not ready.  
**Solution:**  
- Validate the ALB Target Group health check settings.  
- Ensure the WordPress health check endpoint is created and reachable in `user_data`.

---

### 5. SSM Connection Fails
**Cause:** Missing SSM IAM policy or instance not registered.  
**Solution:**  
- Confirm the `AmazonSSMManagedInstanceCore` policy is attached to the instance IAM role.  
- Check Systems Manager → Managed Instances for registration status.

---

### 6. Security Group is Too Open
**Cause:** Default wide-open SSH (0.0.0.0/0) or unrestricted outbound rules.  
**Solution:**  
- Limit `ssh_allowed_cidr` to trusted IPs in production.  
- Restrict outbound rules to required destinations only.

---

### 7. KMS Decryption Fails
**Cause:** Incorrect KMS permissions or wrong KMS Key ARN.  
**Solution:**  
- Check that the IAM role has `kms:Decrypt` permission.  
- Validate the `kms_key_arn` used.

---

### 8. S3 Access Denied Errors
**Cause:** Missing or incorrect S3 bucket policy or IAM permissions.  
**Solution:**  
- Review the S3 bucket policy for required permissions.  
- Ensure the `s3_access_policy` is attached and correct ARNs are provided.

---

### 9. CloudWatch Alarms Do Not Trigger
**Cause:** Alarms disabled or metric misconfiguration.  
**Solution:**  
- Verify `enable_*_alarm` variables are set to `true`.  
- Review thresholds and metric dimensions in alarm configurations.

---

### 10. Frequent Instance Replacement in ASG
**Cause:** Misconfigured termination policies or overly aggressive scaling thresholds.  
**Solution:**  
- Check `termination_policies`.  
- Increase cooldown periods and fine-tune scaling thresholds to reduce churn.

---

## References

- [AWS Auto Scaling](https://docs.aws.amazon.com/autoscaling/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS Systems Manager (SSM)](https://docs.aws.amazon.com/systems-manager/)