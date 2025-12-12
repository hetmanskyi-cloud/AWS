# AWS WordPress Terraform Infrastructure

<div align="center">

![Terraform](https://img.shields.io/badge/Terraform-%237B42BC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-000000?style=for-the-badge&logo=ansible&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-%23117AC9.svg?style=for-the-badge&logo=wordpress&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-005C84?style=for-the-badge&logo=mysql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Amazon VPC](https://img.shields.io/badge/Amazon_VPC-FF9900?style=for-the-badge&logo=amazon-vpc&logoColor=white)
![NAT Gateway](https://img.shields.io/badge/NAT_Gateway-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon_S3-569A31?style=for-the-badge&logo=amazon-s3&logoColor=white)
![Amazon Route 53](https://img.shields.io/badge/Amazon_Route_53-FF9900?style=for-the-badge&logo=amazon-route-53&logoColor=white)
![Amazon CloudFront](https://img.shields.io/badge/Amazon_CloudFront-FF9900?style=for-the-badge&logo=amazon-cloudfront&logoColor=white)
![AWS Lambda](https://img.shields.io/badge/AWS_Lambda-FF9900?style=for-the-badge&logo=aws-lambda&logoColor=white)
![AWS KMS](https://img.shields.io/badge/AWS_KMS-FF9900?style=for-the-badge&logo=aws-key-management-service&logoColor=white)
![Amazon EFS](https://img.shields.io/badge/Amazon_EFS-FF9900?style=for-the-badge&logo=amazon-elastic-file-system&logoColor=white)
![Amazon DynamoDB](https://img.shields.io/badge/Amazon_DynamoDB-4053D6?style=for-the-badge&logo=amazon-dynamodb&logoColor=white)
![Amazon SQS](https://img.shields.io/badge/Amazon_SQS-FF4F8B?style=for-the-badge&logo=amazon-sqs&logoColor=white)
![AWS Certificate Manager](https://img.shields.io/badge/AWS_Certificate_Manager-FF9900?style=for-the-badge&logo=aws-certificate-manager&logoColor=white)
![AWS Secrets Manager](https://img.shields.io/badge/AWS_Secrets_Manager-FF9900?style=for-the-badge&logo=aws-secrets-manager&logoColor=white)
![Application Load Balancer](https://img.shields.io/badge/Application_Load_Balancer-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Auto Scaling Group](https://img.shields.io/badge/Auto_Scaling_Group-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![AWS Client VPN](https://img.shields.io/badge/AWS_Client_VPN-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![VPC Interface Endpoints](https://img.shields.io/badge/VPC_Interface_Endpoints-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![AWS CloudTrail](https://img.shields.io/badge/AWS_CloudTrail-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Amazon CloudWatch](https://img.shields.io/badge/Amazon_CloudWatch-FF9900?style=for-the-badge&logo=amazon-cloudwatch&logoColor=white)
![Amazon SNS](https://img.shields.io/badge/Amazon_SNS-FF9900?style=for-the-badge&logo=amazon-sns&logoColor=white)

</div>

## Status
[![Terraform CI](https://github.com/sky/AWS/actions/workflows/terraform.yml/badge.svg)](https://github.com/sky/AWS/actions/workflows/terraform.yml)
[![ShellCheck](https://github.com/sky/AWS/actions/workflows/terraform.yml/badge.svg?event=push&branch=main&workflow=shellcheck)](https://github.com/sky/AWS/actions/workflows/terraform.yml)

This repository provides a production-ready, modular, and secure Infrastructure as Code (IaC) implementation for deploying a scalable WordPress application on AWS using Terraform. It adheres to AWS and DevOps best practices, emphasizing automation, monitoring, and security.

## Project Overview

This project focuses on automating the deployment and management of a WordPress environment on AWS. Key aspects include:

*   **Scalability**: Designed to handle varying loads through Auto Scaling Groups.
*   **Security**: Implements best practices for network, application, and data security, including WAF, KMS encryption, and IAM least privilege.
*   **Modularity**: Built with reusable Terraform modules for clear organization and easy maintenance.
*   **Automation**: Leverages Terraform for infrastructure provisioning and Ansible for application deployment.

## Technologies Used

*   **Infrastructure as Code**: Terraform
*   **Configuration Management**: Ansible
*   **Cloud Provider**: AWS
*   **CI/CD**: GitHub Actions
*   **Monitoring & Logging**: Amazon CloudWatch, AWS CloudTrail
*   **Security Scanning**: tfsec, Checkov, TFLint, ShellCheck

## Getting Started

For detailed instructions on how to set up, deploy, and manage the AWS WordPress infrastructure, please refer to the [Terraform Documentation](./terraform/README.md).

## Operational Guide

For day-to-day operational procedures, troubleshooting, and maintenance tasks, consult the [Operational Runbook](./runbook.md).

## License

This project is licensed under the [MIT License](./LICENSE).
