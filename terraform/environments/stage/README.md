# AWS WordPress Project - Staging (`stage`) Environment

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Architecture and Deployment Strategy](#2-architecture-and-deployment-strategy)
  - [2.1. Diagram](#21-diagram)
  - [2.2. Key Configuration Choices](#22-key-configuration-choices)
- [3. How to Deploy](#3-how-to-deploy)
- [4. Local Prerequisites](#4-local-prerequisites)
- [5. Key Operational Workflows](#5-key-operational-workflows)
  - [5.1. Golden AMI Workflow](#51-golden-ami-workflow)
  - [5.2. Secrets Rotation](#52-secrets-rotation)
  - [5.3. Shutting Down the Environment](#53-shutting-down-the-environment)
- [6. Accessing the Environment](#6-accessing-the-environment)
- [7. Primary Outputs](#7-primary-outputs)

---

## 1. Overview

This document describes the configuration of the **staging (`stage`) environment** for the WordPress on AWS project.

**Key Characteristics:**
- **Purpose:** Serves as a pre-production environment for integration testing, load testing, and final validation before deploying to production. It is designed to mirror the production environment as closely as possible.
- **Region:** `eu-west-1`.
- **Enhanced Monitoring & Logging:** Compared to `dev`, this environment has more robust monitoring and logging enabled by default to facilitate thorough testing and performance analysis.

---

## 2. Architecture and Deployment Strategy

### 2.1. Diagram

The following diagram illustrates the potential architecture of the `stage` environment. Solid-line components are generally enabled by default in `stage`, while dashed-line components are optional and can be enabled via feature flags for specific testing scenarios.

```mermaid
graph TD
    subgraph "Staging Environment (stage)"
        direction LR

        subgraph "Core Services"
            VPC(VPC)
            ALB(ALB)
            ASG(ASG)
            RDS(RDS Database)
            ElastiCache(Redis)
            S3(S3 Buckets)
            KMS(KMS Key)
            SecretsManager(Secrets Manager)
            SNS(SNS Topics)
            CloudTrail(CloudTrail)
            CloudFront(CloudFront + WAF)
            ClientVPN(Client VPN)
        end

        subgraph "Optional Services"
            style OptionalServices fill:#f8f9fa,stroke:#adb5bd,stroke-dasharray: 4 4
            EFS(EFS File System)

            subgraph Lambda_Pipeline [Image Processing Pipeline]
                style Lambda_Pipeline fill:#f8f9fa,stroke:#adb5bd,stroke-dasharray: 4 4
                Lambda(Lambda)
                SQS(SQS)
                DynamoDB(DynamoDB)
            end

            subgraph CustomDomain [Custom Domain]
                style CustomDomain fill:#f8f9fa,stroke:#adb5bd,stroke-dasharray: 4 4
                ACM(ACM Certificate)
                Route53(Route 53 DNS)
            end
        end

        %% Connections
        Internet([Internet]) --> ClientVPN
        Internet --> CloudFront

        CloudFront -->|"x-custom-origin-verify"| ALB
        CloudFront -->|"OAC"| S3(wordpress_media)

        ClientVPN -->|Secure Access| VPC

        ALB --> ASG
        ASG --> RDS
        ASG --> ElastiCache
        ASG --> EFS

        ASG --"Reads Secrets"--> SecretsManager
        RDS --"Reads Secrets"--> SecretsManager
        ElastiCache --"Reads Secrets"--> SecretsManager

        KMS --"Encrypts"--> RDS
        KMS --"Encrypts"--> ElastiCache
        KMS --"Encrypts"--> S3
        KMS --"Encrypts"--> SecretsManager
        KMS --"Encrypts"--> CloudTrail
        KMS --"Encrypts"--> SNS
        KMS --"Encrypts"--> SQS

        S3(wordpress_media) --"s3:ObjectCreated"--> SQS
        SQS --> Lambda
        Lambda --> DynamoDB
        Lambda --> S3

        Route53 --> CloudFront
        ACM --> CloudFront
    end

    %% Style Definitions
    classDef network fill:#cce5ff,stroke:#66a3ff,color:#004085
    classDef compute fill:#d4edda,stroke:#77c289,color:#155724
    classDef datastore fill:#e0cce6,stroke:#a673b2,color:#381640
    classDef security fill:#f8d7da,stroke:#f58fa0,color:#721c24
    classDef cdn fill:#fff3cd,stroke:#f5d04d,color:#856404
    classDef integration fill:#d1ecf1,stroke:#74c6d4,color:#0c5460
    classDef access fill:#e9ecef,stroke:#adb5bd,color:#343a40
    classDef optional stroke-dasharray: 3 3,color:#555

    %% Apply Styles
    class VPC,ALB network
    class ASG compute
    class RDS,ElastiCache,S3,DynamoDB,EFS datastore
    class KMS,SecretsManager security
    class CloudFront,Route53,ACM cdn
    class Lambda,SQS,SNS integration
    class ClientVPN,CloudTrail access

    class EFS,Lambda,SQS,DynamoDB,ACM,Route53 optional
```

### 2.2. Key Configuration Choices

- **Deployment Strategy (Golden AMI):**
  - The `stage` environment uses a **Golden AMI** deployment strategy for its EC2 instances. This is a fundamental difference from the `dev` environment.
  - Instances are launched from a pre-built, hardened AMI that is created and tested in the `dev` environment (see "Golden AMI Workflow" below).
  - At launch, instances use the `user_data_runtime.sh.tpl` template, which only injects runtime configurations (e.g., fetching secrets) rather than performing a full software installation. This results in much faster and more consistent deployments.
  - The `use_ansible_deployment` variable is set to `false` to reflect this.

- **Monitoring & Logging (Enhanced):**
  - **Status:** `Enabled`.
  - **Details:** Unlike `dev`, the `stage` environment has most monitoring and logging features enabled by default to allow for proper performance and security analysis. This includes:
    - Scaling alarms for the ASG.
    - Low storage alarms for RDS.
    - ALB access logging to S3.
    - CloudTrail logging to S3.
    - WAF logging via Kinesis Firehose for both ALB and CloudFront.
    - S3 bucket versioning is enabled.

- **Networking & Compute:**
  - The VPC and subnet layout is identical to `dev`.
  - ASG and RDS instances may use more powerful instance types than `dev`, and auto-scaling is enabled. These are configured in `terraform.tfvars`.

---

## 3. How to Deploy

### State Backend Warning
This environment currently uses a **local backend** to store the Terraform state file (`terraform.tfstate`). For team-based development, configure the S3 remote backend by uncommenting and filling out `remote_backend.tf`.

### Deployment Instructions
1. Navigate to the environment directory:
   ```bash
   cd environments/stage
   ```
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Apply the configuration. Ensure you are using the correct Golden AMI ID in `terraform.tfvars`.
   ```bash
   terraform apply
   ```
---

## 4. Local Prerequisites

To successfully deploy and manage this environment, the following tools must be installed on your local machine:

- **Terraform (`~> 1.12`)**: To manage infrastructure as code.
- **AWS CLI**: To interact with your AWS account. Ensure it is configured with the necessary credentials.
- **Make**: To use the automated AMI promotion workflow.
- **Ansible**: Although `stage` instances do not run Ansible on boot, it is required for the *creation* of the Golden AMI in the `dev` environment.

---

## 5. Key Operational Workflows

### 5.1. Golden AMI Workflow
The `stage` environment consumes a pre-built "Golden AMI" that is produced by the `dev` environment's "factory" process. Promoting a new AMI to `stage` is an automated, single-command operation.

**To update the AMI used by this environment:**
- Run the following command from the root `terraform/` directory:
  ```bash
  make use-ami TARGET_ENV=stage SOURCE_ENV=dev
  ```
- **What it does:** This command reads the latest tested Golden AMI ID from the `dev` environment's history (`environments/dev/ami_history/ami_id.txt`), updates the `ami_id` variable in this environment's (`stage`) `terraform.tfvars` file, and commits the change to Git.
- **After running `make`:** Run `terraform plan` and `terraform apply` in the `stage` directory to roll out the new AMI. The Auto Scaling Group will perform a rolling refresh to launch new instances with the updated image.

### 5.2. Secrets Rotation
This project uses an IaC-driven approach to rotate secrets (e.g., database password, WordPress salts).

1.  **Update Secret Version**: Change the value of the `secrets_version` variable in `terraform.tfvars`.
2.  **Apply Changes**: Run `terraform apply`. This will regenerate the random passwords/keys and update the values in AWS Secrets Manager.
3.  **Roll Out to Application**: The running EC2 instances will not automatically pick up the new secrets. You must force the Auto Scaling Group to launch new instances, which will fetch the new secrets on boot. This can be done via the AWS Console or by running:
    ```bash
    aws autoscaling start-instance-refresh --auto-scaling-group-name <asg-name>
    ```
    *(Replace `<asg-name>` with the actual name of the Auto Scaling Group from Terraform outputs.)*

### 5.3. Shutting Down the Environment
To avoid incurring costs when the environment is not in use, you can destroy all provisioned resources:
```bash
terraform destroy
```

---

## 6. Accessing the Environment

Access methods are identical to the `dev` environment.

### Website Access
The public URL for the WordPress site is available as a Terraform output:
```bash
terraform output -raw alb_dns_name
```

### WordPress Admin Panel (`/wp-admin/`)
Access to the admin panel is blocked by the WAF and is only permitted from an active Client VPN session.

### Client VPN Connection
1.  **Get the `.ovpn` configuration file:**
    ```bash
    terraform output -raw client_vpn_config_file > wordpress-stage.ovpn
    ```
2.  **Import and Connect:** Import the `wordpress-stage.ovpn` file into your AWS VPN Client or any other OpenVPN-compatible client and connect.
3.  Once connected, you will be able to access the `/wp-admin/` path on the site URL.

---

## 7. Primary Outputs

- `alb_dns_name`: The DNS name of the Application Load Balancer to access the site.
- `db_host`: The hostname of the RDS database instance.
- `db_endpoint`: The full endpoint of the RDS instance.
- `asg_id`: The ID of the Auto Scaling Group.
- `kms_key_arn`: The ARN of the master KMS key.
