# AWS Infrastructure as Code (IaC) Project

---

This repository contains a production-ready, modular, and secure Infrastructure as Code (IaC) implementation using **Terraform** to deploy a scalable WordPress application on AWS. The infrastructure is built following AWS and DevOps best practices with automation, monitoring, and security in mind.

---

## Table of Contents

- [1. Project Structure](#1-project-structure)
- [2. Infrastructure Overview](#2-infrastructure-overview)
- [3. Terraform Modules](#3-terraform-modules)
- [4. Supported Environments](#4-supported-environments)
- [5. Getting Started](#5-getting-started)
  - [5.1 Makefile Automation](#51-makefile-automation)
- [6. Key Variables (in terraform.tfvars)](#6-key-variables-in-terraformtfvars)
- [7. Security & Secrets](#7-security--secrets)
- [8. Monitoring & Observability](#8-monitoring--observability)
- [9. Useful Terraform Commands](#9-useful-terraform-commands)
- [10. Best Practices](#10-best-practices)
- [11. Troubleshooting](#11-troubleshooting)
- [12. References](#12-references)
- [13. License](#13-license)

---

## 1. Project Structure

<pre>
📦 🟧 <b>project</b>
 ┣ 📂 🟧 <b>aws</b>
 ┃ ┣ 📂 🟩 <span>terraform/</span>
 ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>terraform.tfvars</span>
 ┃ ┃ ┣ 📄 🟩 <span>providers.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>remote_backend.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>cloudwatch.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>cloudtrail.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>sns_topics.tf</span>
 ┃ ┃ ┣ 📄 🟩 <span>secrets.tf</span>
 ┃ ┃ ┣ 📄 Makefile
 ┃ ┃ ┣ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┣ 📂 🟦 <span>templates/</span>
 ┃ ┃ ┃ ┣ 📄 🟦 <span>user_data.sh.tpl</span>
 ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┣ 📂 🟠 <span>scripts/</span>
 ┃ ┃ ┃ ┣ 📄 🟠 <span>deploy_wordpress.sh</span>
 ┃ ┃ ┃ ┣ 📄 🟠 <span>healthcheck.php</span>
 ┃ ┃ ┃ ┣ 📄 🟠 <span>debug_monitor.sh</span>
 ┃ ┃ ┃ ┣ 📄 🟠 <span>fix_php_encoding.sh</span>
 ┃ ┃ ┃ ┣ 📄 🟠 <span>check_aws_resources.sh</span>
 ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┗ 📂 🟨 <b>modules/</b>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>vpc/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>endpoints_routes.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>flow_logs.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>nacl.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>kms/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>key.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>metrics.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>s3/</b> 
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>policies.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>lifecycle.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>replication.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>dynamodb.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>rds/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>security_group.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>iam.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>metrics.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>elasticache/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>security_group.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>metrics.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>alb/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>security_group.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>waf.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>firehose.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>metrics.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┣ 📂 🟨 <b>asg/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>launch_template.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>iam.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>security_group.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>metrics.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┃ ┃ ┗ 📂 🟨 <b>interface_endpoints/</b>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>main.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>security_group.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>variables.tf</span>
 ┃ ┃ ┃ ┃ ┣ 📄 🟩 <span>outputs.tf</span>
 ┃ ┃ ┃ ┃ ┗ 📄 🟪 <span>README.md</span>   # You are here
 ┃ ┣ 📂 🟧 <span>.github/</span>
 ┃ ┃ ┣ 📄 terraform.yml
 ┃ ┃ ┗ 📄 🟪 <span>README.md</span>
 ┃ ┣ 📄 LICENSE
 ┃ ┣ 📄 .gitignore
 ┃ ┗ 📄 🟪 <span>README.md</span>
 ┗ 📂 🟧 <b>wordpress</b>
   ┗ 📦 <i>WordPress Git mirror</i>
</pre>

<div align="center">
**Color Legend:**  
🟧 Repository | 🟨 Module | 🟩 Terraform | 🟦 Template | 🟠 Script | 🟪 README
</div>

---

## 2. Infrastructure Overview

The infrastructure provisions a scalable and secure WordPress environment including:

- **Virtual Private Cloud (VPC)** with public and private subnets
- **EC2 Auto Scaling Group (ASG)** hosting WordPress
- **Application Load Balancer (ALB)** with optional HTTPS and WAF
- **Amazon RDS (MySQL)** for WordPress data
- **Amazon ElastiCache (Redis)** for session caching
- **S3 Buckets** for media and deployment scripts
- **KMS** for encryption of logs, buckets, and Redis
- **CloudWatch Logs and Alarms** for observability
- **Interface VPC Endpoints** to support private subnets without NAT

---

## 3. Terraform Modules

| Module               | Description                                             |
|----------------------|---------------------------------------------------------|
| `vpc`                | Manages networking resources including subnets, IGW, RT |
| `kms`                | Creates KMS keys for encryption                         |
| `s3`                 | Configures S3 buckets for media, scripts, and logging   |
| `rds`                | Deploys MySQL database in private subnet                |
| `elasticache`        | Creates Redis replication group with monitoring         |
| `alb`                | ALB + HTTPS + WAF + logging + CloudWatch alarms         |
| `asg`                | EC2 Launch Template, ASG with health checks and alarms  |
| `interface_endpoints`| Adds SSM, CloudWatch, and KMS interface endpoints       |

All modules are conditional and configurable for multiple environments (dev/stage/prod).

---

## 4. Supported Environments

The infrastructure is environment-agnostic and supports development, staging, and production through the `terraform.tfvars` file.

---

## 5. Getting Started

> Prerequisites: Terraform v1.5+, AWS CLI, valid IAM credentials

```bash
cd aws/terraform
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

---  

## 5.1 Makefile Automation

A `Makefile` is included in the /terraform directory to streamline common operations like `terraform init`, `plan`, `apply`, and `destroy`. This helps reduce repetitive typing and enforces consistent usage across environments.

```bash
make init         # Initialize Terraform
make plan         # Show planned changes
make apply        # Apply changes to infrastructure
make destroy      # Tear down infrastructure
```
This helps ensure consistent usage across environments and avoids repetitive typing.

---

## 6. Key Variables (in terraform.tfvars)

```hcl
aws_region           = "eu-west-1"
name_prefix          = "dev"
environment          = "dev"
ami_id               = "ami-0abc123..."
instance_type        = "t2.micro"
autoscaling_min      = 1
autoscaling_max      = 3
db_port              = 3306
redis_port           = 6379
enable_https_listener = true
enable_interface_endpoints = true
enable_cloudwatch_logs = true
```

---

## 7. Security & Secrets

- **IAM Least Privilege** enforced for EC2 roles
- **Secrets Manager** stores Redis and WordPress secrets
- **KMS encryption** used for logs, S3, Redis
- **WAF protection** enabled (optional)
- **Security Groups and NACLs** tightly scoped per environment
- **HTTPS via ACM** can be enabled if a valid certificate is provided

---

## 8. Monitoring & Observability

- CloudWatch Alarms for:
  - EC2 CPU, network, status
  - Redis memory, CPU, replication
  - ALB 5XX errors, latency, unhealthy hosts
- Optional SNS notifications
- Log delivery to S3 with retention policies

---

## 9. Useful Terraform Commands

```bash
terraform fmt -recursive         # Format code
terraform validate               # Syntax validation
terraform plan -var-file=...     # Preview changes
terraform apply -var-file=...    # Deploy changes
terraform destroy -var-file=...  # Tear down infrastructure
```

---

## 10. Best Practices

- Avoid hardcoding sensitive values; use Secrets Manager
- Tag all resources with environment and name prefix
- Use modules with conditional logic for flexibility
- Test using `terraform plan` before applying
- Monitor WAF logs and CloudWatch alerts

---

## 11. Troubleshooting

If EC2 has no internet access:
- Ensure public subnet has correct route to IGW
- Confirm security group and NACL rules

If WordPress is not installed:
- Check rendered user_data script
- Validate that deploy script and wp-config are reachable

---

## 12. References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html)
- [WordPress on AWS](https://aws.amazon.com/getting-started/hands-on/deploy-wordpress-with-amazon-rds/)

---

## 13. License

This project is licensed under the [MIT License](./LICENSE).