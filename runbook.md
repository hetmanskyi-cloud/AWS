# Operational Runbook: AWS WordPress Terraform

## 1. Overview

This runbook serves as a guide for day-to-day operations, maintenance, and troubleshooting of the AWS WordPress infrastructure deployed via Terraform. It is intended for operations teams, system administrators, and anyone responsible for the uptime and health of the WordPress application.

For detailed information on the infrastructure's architecture and deployment, refer to the main [README.md](../README.md) and the [Terraform Documentation](./terraform/README.md).

## 2. Deployment & Updates

### 2.1 Initial Deployment

Refer to the "Getting Started" section in the [Terraform Documentation](./terraform/README.md) for initial deployment steps using Terraform.

### 2.2 Updating WordPress Application Code

To update the WordPress application version or any related code, follow these steps:

1.  **Update `terraform/environments/<env>/variables.tf`**:
    *   Change the `wordpress_version` variable to the desired version.
    *   If using Golden AMI strategy, update the `ami_id` variable with the ID of the new Golden AMI.
2.  **Generate/Update Golden AMI (if applicable)**:
    *   If `use_ansible_deployment` is `false` (e.g., in `stage` or `prod`), a new Golden AMI needs to be prepared using the Ansible playbook `ansible/playbooks/prepare-golden-ami.yml`.
    *   Ensure the latest WordPress version and configurations are baked into the new AMI.
3.  **Run Terraform Apply**:
    ```bash
    cd terraform/environments/<env>
    terraform init
    terraform plan -var-file="terraform.tfvars" -out="tfplan"
    terraform apply "tfplan"
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
2.  **SSH into EC2 Instances**:
    *   Connect to one of the EC2 instances in the Auto Scaling Group.
    *   Check web server (Nginx/Apache) logs: `/var/log/nginx/error.log`, `/var/log/apache2/error.log`.
    *   Check PHP-FPM logs: `/var/log/php-fpm/www-error.log` (path may vary).
    *   Check WordPress debug logs (if enabled): `wp-content/debug.log`.
    *   Verify MySQL connectivity from the EC2 instance to the RDS endpoint.
    *   Verify ElastiCache (Redis) connectivity.
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
3.  **Investigate**: Use CloudWatch metrics, logs, and SSH access to diagnose the root cause.
4.  **Resolve & Document**: Address the issue and, if a new pattern, update this runbook.

### 4.2 Logging

*   **ALB Access Logs**: Stored in S3 (configured in `terraform/modules/alb/`).
*   **CloudFront Access Logs**: Stored in S3 (configured in `terraform/modules/cloudfront/`).
*   **EC2 System Logs**: Accessible via SSH (`/var/log/syslog`, `dmesg`).
*   **WordPress/PHP Logs**: Located on EC2 instances (`/var/log/nginx/error.log`, `wp-content/debug.log`).

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

## 6. Security Procedures

### 6.1 Regular Security Audits

*   Periodically review AWS security group rules, NACLs, and IAM policies.
*   Keep WordPress core, themes, and plugins updated to the latest secure versions.
*   Monitor WAF logs for suspicious activity.

### 6.2 Secret Rotation

*   **Secrets Manager**: Utilize AWS Secrets Manager for database credentials and other sensitive information.
*   Implement a regular rotation schedule for secrets managed by Secrets Manager. This can often be automated using AWS Lambda functions.

### 6.3 Incident Response

*   **Isolate**: If a security incident is detected, immediately isolate affected instances from the network (e.g., modify security group to deny all inbound traffic).
*   **Investigate**: Collect logs, forensic data, and identify the attack vector.
*   **Remediate**: Patch vulnerabilities, remove malicious code, and restore from a known good backup if necessary.
*   **Document**: Record all steps taken during the incident response.
