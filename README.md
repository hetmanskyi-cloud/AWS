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

</div>

This repository provides a production-ready, modular, and secure Infrastructure as Code (IaC) implementation for deploying a scalable WordPress application on AWS using Terraform. It adheres to AWS and DevOps best practices, emphasizing automation, monitoring, and security.

## Project Overview

This project focuses on automating the deployment and management of a WordPress environment on AWS. Key aspects include:

*   **Scalability**: Designed to handle varying loads through Auto Scaling Groups.
*   **Security**: Implements best practices for network, application, and data security, including WAF, KMS encryption, and IAM least privilege.
*   **Modularity**: Built with reusable Terraform modules for clear organization and easy maintenance.
*   **Automation**: Leverages Terraform for infrastructure provisioning and Ansible for application deployment.

## Getting Started

For detailed instructions on how to set up, deploy, and manage the AWS WordPress infrastructure, please refer to the [Terraform Documentation](./terraform/README.md).

## Operational Guide

For day-to-day operational procedures, troubleshooting, and maintenance tasks, consult the [Operational Runbook](./runbook.md).

## License

This project is licensed under the [MIT License](./LICENSE).
