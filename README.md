# AWS Infrastructure as Code with Terraform

A comprehensive Terraform project for deploying a secure, scalable, and highly available AWS infrastructure with WordPress hosting capabilities.

## Architecture Overview

This project implements a production-ready AWS infrastructure with the following components:

```
                                     Internet
                                        │
                                        ▼
                                  ┌──────────┐
                                  │    WAF   │
                                  └────┬─────┘
                                       │
                                       ▼
                                  ┌──────────┐
                                  │    ALB   │◄───── CloudWatch Alarms
                                  └────┬─────┘       SNS Notifications
                                       │
                                       ▼
                                  ┌──────────┐
                                  │    ASG   │◄───── Launch Template
                                  └────┬─────┘       Auto Scaling Policies
                                       │
                                       ▼
┌─────────────┐              ┌─────────────────┐              ┌─────────────┐
│             │              │                 │              │             │
│  RDS MySQL  │◄────────────►│  EC2 Instances  │◄────────────►│ ElastiCache │
│  (Primary/  │              │   (WordPress)   │              │   (Redis)   │
│   Replica)  │              │                 │              │             │
└─────────────┘              └─────────────────┘              └─────────────┘
       ▲                              ▲                              ▲
       │                              │                              │
       └──────────────────────────────┼──────────────────────────────┘
                                      │
                                      ▼
                               ┌─────────────┐
                               │     VPC     │
                               │             │
                               │ Public and  │
                               │   Private   │
                               │  Subnets    │
                               └─────────────┘
                                      ▲
                                      │
                                      ▼
                               ┌─────────────┐
                               │     S3      │◄───── CloudTrail
                               │  Buckets    │       ALB Logs
                               └─────────────┘       WordPress Media
                                      ▲
                                      │
                                      ▼
                               ┌─────────────┐
                               │    KMS      │
                               │  Encryption │
                               └─────────────┘
```

## Features

- **Secure Networking**: VPC with public and private subnets across multiple Availability Zones, Network ACLs, and VPC Flow Logs
- **High Availability**: Auto Scaling Groups, Multi-AZ RDS, and ElastiCache Redis with replication
- **Security**: WAF protection, KMS encryption, HTTPS enforcement, and secure IAM policies
- **Monitoring**: CloudWatch alarms, SNS notifications, and comprehensive logging
- **Scalability**: Auto Scaling policies based on CPU and memory utilization
- **WordPress Hosting**: Pre-configured WordPress deployment with database and caching
- **Disaster Recovery**: Cross-region S3 replication and database backups
- **Cost Optimization**: Lifecycle policies, right-sized instances, and efficient resource usage

## Modules

This project consists of the following modules:

| Module | Description |
|--------|-------------|
| [vpc](/terraform/modules/vpc) | Creates a VPC with public and private subnets, route tables, NACLs, and VPC endpoints |
| [alb](/terraform/modules/alb) | Provisions an Application Load Balancer with WAF, security groups, and monitoring |
| [asg](/terraform/modules/asg) | Sets up Auto Scaling Groups with launch templates and scaling policies |
| [rds](/terraform/modules/rds) | Configures RDS MySQL instances with Multi-AZ support and monitoring |
| [elasticache](/terraform/modules/elasticache) | Deploys ElastiCache Redis clusters with replication and monitoring |
| [s3](/terraform/modules/s3) | Creates S3 buckets with encryption, lifecycle policies, and replication |
| [kms](/terraform/modules/kms) | Manages KMS keys for encryption of resources |
| [interface_endpoints](/terraform/modules/interface_endpoints) | Establishes VPC interface endpoints for AWS services |

## Prerequisites

- Terraform v1.11+
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create the required resources
- Domain name (if using HTTPS with ACM certificates)

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd AWS
```

### 2. Configure Variables

Create a `terraform.tfvars` file based on the example provided:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit the `terraform.tfvars` file to customize your deployment:

```hcl
# General Configuration
aws_region         = "eu-west-1"
replication_region = "us-east-1"
environment        = "prod"
name_prefix        = "myproject"
aws_account_id     = "123456789012"

# VPC Configuration
vpc_cidr_block = "10.0.0.0/16"
# ... additional variables
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan -out=tfplan
```

### 5. Apply the Configuration

```bash
terraform apply tfplan
```

## Remote State Management

This project uses S3 for remote state storage with DynamoDB for state locking. The configuration is in `remote_backend.tf`.

To enable remote state storage:

1. First, deploy the S3 and DynamoDB resources:

```bash
terraform apply -target=module.s3 -target=aws_dynamodb_table.terraform_locks
```

2. Uncomment the backend configuration in `remote_backend.tf`
3. Run `terraform init` again to migrate the state to S3

## Security Considerations

- All sensitive data is encrypted using KMS
- Public access to S3 buckets is blocked
- HTTPS is enforced for all web traffic
- Security groups follow the principle of least privilege
- IAM roles use minimal permissions required for functionality
- VPC endpoints are used to keep traffic within the AWS network

## Cost Optimization

- Use Auto Scaling to match capacity with demand
- Configure lifecycle policies for S3 objects
- Enable bucket keys for KMS cost reduction
- Monitor CloudWatch metrics for resource utilization
- Consider reserved instances for predictable workloads

## Maintenance and Operations

### Updating WordPress

WordPress updates can be managed through the admin interface or by updating the AMI used by the Auto Scaling Group.

### Backups

- Database: Automated RDS snapshots
- Media files: S3 cross-region replication
- Configuration: Terraform state in S3 with versioning

### Monitoring

- CloudWatch dashboards for key metrics
- SNS notifications for alarms
- CloudTrail for API activity logging

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   - Check CloudTrail logs for API errors
   - Verify IAM permissions

2. **Website Unavailability**
   - Check ALB health checks
   - Verify security group rules
   - Inspect Auto Scaling Group status

3. **Performance Issues**
   - Review CloudWatch metrics
   - Check ElastiCache hit ratio
   - Monitor RDS performance insights

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with a clear description of changes

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)
- [WordPress on AWS](https://aws.amazon.com/blogs/architecture/wordpress-best-practices-on-aws/)