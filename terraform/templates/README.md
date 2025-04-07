# AWS Terraform Templates

---

## 1. Overview

This directory contains Terraform template files used to dynamically generate scripts and configurations required during infrastructure deployment. The primary template, `user_data.sh.tpl`, generates the EC2 instance bootstrap script for automated WordPress deployment.

---

## 2. Prerequisites / Requirements

- **Terraform Project Context**:
  - Templates are designed for use within this Terraform project and depend on specific variables.

- **AWS CLI**:
  - `user_data.sh.tpl` assumes AWS CLI v2 is installed or installable on the EC2 instance.

- **IAM Permissions**:
  - The EC2 instance requires IAM permissions to access Secrets Manager and optionally S3 for script downloads.

---

## 3. Architecture Diagram

```mermaid
graph TD
  %% Main Components
  EC2["EC2 Instance"]
  UserData["user_data.sh.tpl"]
  AWSCLI["AWS CLI v2"]
  EnvVars["Environment Variables"]
  SecretsManager["AWS Secrets Manager"]
  WPScript["WordPress Deployment Script"]
  WordPress["WordPress Configuration"]
  Healthcheck["Healthcheck Endpoint"]
  WebServer["Nginx + PHP-FPM"]
  RDSSSL["RDS SSL Certificate"]
  RedisAuth["Redis Authentication"]
  RetryParams["Retry Parameters"]
  
  %% S3 Components
  S3Script["S3 Bucket<br>(Deployment Scripts)"]
  
  %% Main Flow
  EC2 -->|"Startup"| UserData
  UserData -->|"Installs"| AWSCLI
  UserData -->|"Sets"| EnvVars
  UserData -->|"Downloads"| RDSSSL
  UserData -->|"Creates"| Healthcheck
  UserData -->|"Configures"| RetryParams
  EnvVars -->|"Provides Config"| WPScript
  
  %% Script Download Logic
  UserData -->|"Downloads From"| S3Script
  S3Script -->|"Provides"| WPScript
  
  %% Secrets Flow
  UserData -->|"Passes Secret Names"| SecretsManager
  SecretsManager -->|"WordPress Credentials"| WPScript
  SecretsManager -->|"Redis Token"| RedisAuth
  RedisAuth -->|"Secure Connection"| WPScript
  
  %% WordPress Configuration
  WPScript -->|"Configures"| WordPress
  WPScript -->|"Starts"| WebServer
  WebServer -->|"Serves"| WordPress
  
  %% Styling
  classDef compute fill:#FF9900,stroke:#232F3E,color:white
  classDef storage fill:#1E8449,stroke:#232F3E,color:white
  classDef security fill:#DD3522,stroke:#232F3E,color:white
  classDef decision fill:#0066CC,stroke:#232F3E,color:white
  classDef service fill:#7D3C98,stroke:#232F3E,color:white
  classDef network fill:#2E86C1,stroke:#232F3E,color:white
  
  class EC2,UserData,AWSCLI,EnvVars,WPScript,WordPress,Healthcheck,WebServer,RetryParams compute
  class S3Script storage
  class SecretsManager,RedisAuth security
  class RDSSSL network
```
---

## 4. Features

- Dynamic user data generation for EC2 instances
- Automatic retrieval of secrets from AWS Secrets Manager
- Deployment script download from S3
- Configurable environment variable injection for WordPress setup
- RDS SSL certificate download for secure database connections
- Simple healthcheck file creation for ALB health checks

---

## 5. Files Structure

| File               | Description                                                       |
|--------------------|-------------------------------------------------------------------|
| `user_data.sh.tpl` | Template for EC2 User Data script rendering WordPress deployment  |

---

## 6. Required Variables

| Variable                 | Type        | Description                                                           |
|--------------------------|-------------|-----------------------------------------------------------------------|
| `wp_config`              | map(string) | WordPress configuration values                                        |
| `aws_region`             | string      | AWS Region                                                            |
| `wordpress_script_path`  | string      | S3 path to the WordPress deployment script                            |
| `script_content`         | string      | Local script content (uploaded to S3; not used in user_data directly) |
| `healthcheck_s3_path`    | string      | S3 path to healthcheck file (optional)                                |
| `wordpress_secrets_name` | string      | Name of Secrets Manager secret for WordPress                          |
| `redis_auth_secret_name` | string      | Name of Secrets Manager secret for Redis authentication               |
| `retry_max_retries`      | number      | Maximum number of retries for operations                              |
| `retry_retry_interval`   | number      | Interval between retries in seconds                                   |
| `WP_TMP_DIR`             | string      | Temporary directory for WordPress setup (used in deployment)          |
| `WP_PATH`                | string      | WordPress installation path (used in deployment)                      |


---

## 7. Example Usage

```hcl
locals {
  rendered_user_data = templatefile(
    "${path.module}/../../templates/user_data.sh.tpl",
    {
      wp_config              = local.wp_config,
      aws_region             = var.aws_region,
      wordpress_script_path  = local.wordpress_script_path,
      script_content         = local.script_content,
      healthcheck_s3_path    = local.healthcheck_s3_path,
      wordpress_secrets_name = var.wordpress_secrets_name,
      redis_auth_secret_name = var.redis_auth_secret_name,
      retry_max_retries      = local.retry_config.MAX_RETRIES,
      retry_retry_interval   = local.retry_config.RETRY_INTERVAL,
      WP_TMP_DIR             = "/tmp/wordpress-setup",
      WP_PATH                = "/var/www/html"
    }
  )
}

resource "aws_launch_template" "asg_launch_template" {
  user_data = base64encode(local.rendered_user_data)
}
```
---

## 8. Security Considerations / Recommendations

- **Secrets Retrieval**: Sensitive credentials are securely retrieved from AWS Secrets Manager.
- **IAM Restrictions**: Ensure the EC2 instance role has only necessary permissions.
- **No Hardcoded Secrets**: Avoid embedding any sensitive data in templates or variables.

---

## 9. Deployment Process

- The user_data.sh.tpl script is executed when an EC2 instance launches
- AWS CLI is installed if not already present
- Environment variables are exported to /etc/environment for use by the WordPress deployment script
- Amazon RDS root SSL certificate is downloaded for secure database connections
- A simple healthcheck file (`<?php http_response_code(200); ?>`) is created directly in the WordPress directory
- A more complete `healthcheck.php` file may optionally be downloaded from S3 (if `healthcheck_s3_path` is defined)
- The WordPress deployment script is downloaded from S3
- The deployment script is executed to:
  - Retrieve secrets from AWS Secrets Manager
  - Install and configure Nginx and PHP
  - Download and install WordPress
  - Configure WordPress with database and Redis settings
  - Enable Redis Object Cache
  - Download a more comprehensive healthcheck file from S3 (if specified)

---

## 10. Best Practices

- **Validate Templates**: Always validate template rendering before deployment.
- **Use SSM**: Prefer SSM Parameters for non-sensitive configuration.
- **Idempotency**: Ensure the generated user data script is idempotent.
- **Logging**: The script logs all actions to both console and `/var/log/user-data.log` for debugging.
- **Error Handling**: The script uses `set -euxo pipefail` to fail fast on errors and undefined variables.

---

## 11. Integration

- ASG Module – uses the template to generate user data for EC2 instances
- Secrets Manager – provides sensitive data during deployment
- S3 Module – stores deployment scripts and healthcheck files (if enabled)

---

## 12. Future Improvements

- Add support for fetching additional configuration files from S3
- Implement templating logic for multi-application deployment scenarios
- Consider switching to SSM Parameter Store for some environment variables

---

## 13. Troubleshooting and Common Issues

- **Failure to Download Script**: Verify S3 permissions and correct path.
- **Secrets Retrieval Errors**: Check IAM role policies for Secrets Manager access.
- **WordPress Install Fails**: Inspect `/var/log/wordpress_install.log` inside the instance.
- **User Data Fails**: Check `/var/log/user-data.log` for syntax or runtime errors.

---

## 14. Notes

- This template is tightly coupled with the project modules.
- Modifications require testing to prevent deployment failures.
- Designed for EC2 Linux instances with Amazon Linux or Ubuntu base images.

---

## 15. Useful Resources

- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [AWS User Data Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Terraform Templatefile Function](https://developer.hashicorp.com/terraform/language/functions/templatefile)
- [AWS CLI – get-secret-value](https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/get-secret-value.html)
- [RDS SSL Support](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)

---