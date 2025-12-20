# Operational Runbook: AWS WordPress Terraform

## 1. Overview

This runbook serves as a guide for day-to-day operations, maintenance, and troubleshooting of the AWS WordPress infrastructure deployed via Terraform. It is intended for operations teams, system administrators, and anyone responsible for the uptime and health of the WordPress application.

For detailed information on the infrastructure's architecture and deployment, refer to the main [README.md](./README.md) and the [Terraform Documentation](./terraform/README.md).

## 2. Deployment & Updates

### 2.1 Initial Deployment

Refer to the "Getting Started" section in the [Terraform Documentation](./terraform/README.md) for initial deployment steps using Terraform.

### 2.2 Updating WordPress Application Code

To update the WordPress application version or any related code, follow these steps:

1.  **Update `terraform/environments/<env>/terraform.tfvars`**:
    *   Change the `wordpress_version` variable to the desired version (primarily for documentation or if building a new Golden AMI).
    *   If using Golden AMI strategy, update the `ami_id` variable with the ID of the new Golden AMI.

2.  **Generate/Update Golden AMI (if applicable)**:
    *   If `use_ansible_deployment` is `false` (e.g., in `stage` or `prod`), a new Golden AMI needs to be prepared.
    *   This process involves executing commands from the `terraform/` directory:
        1.  Provisioning and hardening an instance in the `dev` environment: `make provision-ami ENV=dev`
        2.  Running smoke tests on the prepared instance: `make test-ami ENV=dev`
        3.  Creating the new AMI: `make create-ami ENV=dev`
        4.  Promoting the AMI to the target environment (e.g., `stage`): `make use-ami TARGET_ENV=stage SOURCE_ENV=dev`
    *   For a complete, detailed walkthrough of the Golden AMI workflow, refer to the "Golden AMI Workflow" section in the [Terraform Documentation](./terraform/README.md).

3.  **Run Terraform Apply**:
    ```bash
    cd terraform/environments/<env>
    terraform init
    terraform apply -var-file="terraform.tfvars" "tfplan"
    ```
    This will trigger an Auto Scaling Group instance refresh, replacing old instances with new ones running the updated application code or AMI.

### 2.3 Applying Infrastructure Changes

For any changes to the Terraform infrastructure code (e.g., changing instance types, adding resources):

1.  **Review Changes**: Carefully review the Terraform code changes.
2.  **Run Terraform Plan**:
    ```bash
    cd terraform/environments/<env>
    terraform init
    terraform plan -var-file="terraform.tfvars" -out="tfplan"
    ```
3.  **Apply Changes**:
    ```bash
    terraform apply "tfplan"
    ```
    Monitor the application during and after the apply process.

## 3. Troubleshooting

### 3.1 WordPress Site is Down/Unresponsive

1.  **Check ALB Target Group Health Checks**:
    *   Go to EC2 Console -> Load Balancers -> Target Groups.
    *   Check the health status of instances registered with the WordPress target group.
    *   If instances are unhealthy, investigate the cause.
2.  **Connect to EC2 Instances via AWS Systems Manager (SSM) Session Manager**:
    *   Connect to one of the EC2 instances in the Auto Scaling Group.
    *   Check web server (Nginx) logs: `/var/log/nginx/error.log`.
    *   Check PHP-FPM logs: `/var/log/php-fpm/www-error.log`, `/var/log/php-fpm/access.log`.
    *   Check WordPress debug logs (if enabled): `/var/log/wordpress.log`.
    *   Check bootstrap logs: `/var/log/user-data.log`, `/var/log/wordpress_install.log` (for `dev` environments).
    *   Verify MySQL connectivity from the EC2 instance to the RDS endpoint.
    *   Verify ElastiCache (Redis) connectivity.
    *   **Check SSM Agent Status**: If you cannot connect via Session Manager, ensure the SSM Agent is running on the instance (`sudo systemctl status amazon-ssm-agent`).
    *   **Use `debug_monitor.sh`**: For real-time log streaming during deployment, use the `debug_monitor.sh` script from the `terraform/scripts/` directory.
3.  **Review CloudWatch Metrics & Logs**:
    *   Check ALB metrics for 5XX errors, latency.
    *   Check EC2 metrics for CPU utilization, memory, network I/O.
    *   Review CloudWatch Logs for application and system errors.

### 3.2 Database Connectivity Issues

1.  **Check RDS Instance Status**:
    *   Go to RDS Console and check the status of the WordPress database instance.
    *   Review recent events and logs.
2.  **Security Group Rules**:
    *   Ensure the security group attached to the EC2 instances allows outbound traffic to the RDS security group on port 3306.
    *   Ensure the RDS security group allows inbound traffic from the EC2 security group on port 3306.
3.  **Network ACLs**:
    *   Verify that Network ACLs for both private subnets and database subnets allow necessary traffic (inbound/outbound on ephemeral ports).

### 3.3 Cache Issues (Redis)

1.  **ElastiCache Status**:
    *   Go to ElastiCache Console and check the status of the Redis replication group.
    *   Review metrics for cache hit ratio, evictions, and connections.
2.  **Security Group Rules**:
    *   Ensure the EC2 security group allows outbound traffic to the ElastiCache security group on port 6379.
    *   Ensure the ElastiCache security group allows inbound traffic from the EC2 security group on port 6379.

## 4. Monitoring & Alerts

### 4.1 CloudWatch Alarms

The infrastructure is configured with various CloudWatch alarms. If an alarm triggers an SNS notification:

1.  **Identify the Alarm**: Check the SNS notification for the alarm name and description.
2.  **Consult Troubleshooting Section**: Use the relevant section in this runbook based on the alarm type (e.g., EC2 CPU utilization, ALB 5XX errors, RDS FreeStorageSpace).
3.  **Investigate**: Use CloudWatch metrics, logs, and SSM Session Manager to diagnose the root cause.
4.  **Resolve & Document**: Address the issue and, if a new pattern, update this runbook.

### 4.2 Logging

*   **ALB Access Logs**: Stored in S3 (configured in `terraform/modules/alb/`).
*   **CloudFront Access Logs**: Delivered via CloudWatch Log Delivery (Logging v2) to S3 (configured in `terraform/modules/cloudfront/`).
*   **EC2 System Logs**: Accessible via SSM Session Manager (`/var/log/syslog`, `dmesg`, `/var/log/ansible_playbook.log` for Ansible deployments, `/var/log/user-data.log`, `/var/log/wordpress_install.log`).
*   **WordPress/PHP Logs**: Located on EC2 instances (`/var/log/nginx/error.log`, `/var/log/php-fpm/www-error.log`, `/var/log/php-fpm/access.log`, `/var/log/wordpress.log`).

## 5. Backup & Restore

### 5.1 RDS Backups

*   **Automated Snapshots**: RDS instances are configured for automated daily snapshots.
*   **Manual Snapshots**: Create a manual snapshot before major changes or upgrades.
    *   Go to RDS Console -> Databases -> Select instance -> Actions -> Take snapshot.
*   **Restoring from Snapshot**:
    *   Go to RDS Console -> Snapshots -> Select snapshot -> Actions -> Restore snapshot.
    *   This will create a *new* RDS instance. You will need to update the WordPress configuration to point to the new endpoint.

### 5.2 S3 Backups (WordPress Media)

*   S3 buckets are versioned (if `enable_versioning` is `true`).
*   Object lifecycle policies manage older versions.
*   To restore specific media files, retrieve them from S3 version history.

## 6. Access Procedures

### 6.1 Accessing the WordPress Admin Panel (`/wp-admin`)

Access to the WordPress admin panel is restricted by the Web Application Firewall (WAF) for security. To gain access, you must connect to the environment's Client VPN.

1.  **Connect to Client VPN**: Use the `.ovpn` configuration file generated by Terraform to establish a VPN connection.
2.  **Access Admin URL**: Once connected, you can navigate to `https://<your-site-url>/wp-admin` in your browser.

### 6.2 Connecting to the Database for Debugging

Direct access to the RDS database from the internet is blocked. In a critical troubleshooting scenario where you need to connect directly to the database, you must use an EC2 instance within the VPC as a bastion host.

1.  **Connect to an EC2 Instance**: Start an SSM Session Manager session to one of the running WordPress EC2 instances.
    ```bash
    aws ssm start-session --target <instance-id>
    ```
2.  **Install MySQL Client**: If not already present, install the MySQL client on the instance:
    ```bash
    sudo apt-get update && sudo apt-get install mysql-client
    ```
3.  **Retrieve Credentials**: Fetch the database credentials from AWS Secrets Manager.
    ```bash
    # You can find the secret name in the Terraform output 'rds_secret_name' or the AWS Console.
    aws secretsmanager get-secret-value --secret-id <rds-secret-name> --query SecretString --output text
    ```
4.  **Connect to RDS**: Use the retrieved credentials and the RDS endpoint (available from Terraform outputs or the AWS RDS Console) to connect.
    ```bash
    mysql -h <rds-endpoint> -u <username> -p
    ```

## 7. Makefile for Automation

Many common operational tasks such as running a full test plan (`plan`), deploying (`apply`), debugging (`debug`), and managing the Golden AMI lifecycle are automated via the `Makefile` located in the root `terraform/` directory. For a full list and description of available commands, please refer to the [Makefile Commands section in the Terraform README](./terraform/README.md#9-makefile-commands).

## 8. Security Procedures

### 8.1 Regular Security Audits

*   Periodically review AWS security group rules, NACLs, and IAM policies.
*   Keep WordPress core, themes, and plugins updated to the latest secure versions.
*   Monitor WAF logs for suspicious activity.

### 8.2 Secret Rotation

This project utilizes an Infrastructure-as-Code (IaC) driven approach for secret rotation, primarily managed via AWS Secrets Manager and Terraform.

1.  **Update Secret Version**: In the `terraform/environments/<env>/terraform.tfvars` file, increment the `secrets_version` variable (e.g., `"v1.0.0"` -> `"v1.0.1"`). This change will signal Terraform to generate new random values for secrets tied to this version.
2.  **Apply Changes**: Run `terraform apply` for the respective environment:
    ```bash
    cd terraform/environments/<env>
    terraform init
    terraform apply -var-file="terraform.tfvars"
    ```
    Terraform will detect the version change, generate new random passwords/keys, and update the values in AWS Secrets Manager.
3.  **Roll Out to Application**: The running EC2 instances will not automatically pick up the new secrets. You must force the Auto Scaling Group to launch new instances, which will fetch the new secrets on boot. This can be done via the AWS Console or by running:
    ```bash
    aws autoscaling start-instance-refresh --auto-scaling-group-name <name_prefix>-asg-<environment>
    ```
    *(Replace `<name_prefix>` and `<environment>` with the actual prefix and environment name from your Terraform outputs.)*
    This will initiate a rolling refresh, ensuring new instances use the updated secrets.

### 8.3 Incident Response

*   **Isolate**: If a security incident is detected, immediately isolate affected instances from the network (e.g., modify security group to deny all inbound traffic).
*   **Investigate**: Collect logs, forensic data, and identify the attack vector.
*   **Remediate**: Patch vulnerabilities, remove malicious code, and restore from a known good backup if necessary.
*   **Document**: Record all steps taken during the incident response.
