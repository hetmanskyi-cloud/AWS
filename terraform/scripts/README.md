# AWS WordPress Deployment Scripts

This directory contains scripts used for deploying, checking, and maintaining WordPress installations on AWS infrastructure. These scripts are designed to work with the Terraform modules in this project.

### Code Structure Overview

| Script                   | Description                                                                                 |
|--------------------------|---------------------------------------------------------------------------------------------|
| `check_aws_resources.sh` | Checks AWS resources (VPC, EC2, RDS, etc.) to identify undeleted or orphaned resources.     |
| `check_server_status.sh` | Performs comprehensive health checks on an EC2 instance running WordPress                   |
| `deploy_wordpress.sh`    | Installs and configures WordPress on an EC2 instance integrated with RDS and ElastiCache.   |
| `healthcheck-1.0.php`    | Simple PHP health check for ALB, returns HTTP 200.                                          |
| `healthcheck-2.0.php`    | Advanced health check verifying PHP, MySQL, Redis, and WordPress REST API.                  |

## Configuration Parameters

### deploy_wordpress.sh

| Parameter                | Description                                            | Required | Default             |
|--------------------------|--------------------------------------------------------|----------|---------------------|
| `DB_HOST`                | RDS endpoint for MySQL database                        | Yes      | -                   |
| `DB_PORT`                | MySQL port (typically 3306)                            | Yes      | 3306                |
| `SECRET_NAME`            | AWS Secrets Manager secret name containing credentials | Yes      | -                   |
| `PHP_VERSION`            | PHP version to install (e.g., "8.3")                   | Yes      | 8.3                 |
| `REDIS_HOST`             | ElastiCache Redis endpoint                             | Yes      | -                   |
| `REDIS_PORT`             | Redis port (typically 6379)                            | Yes      | 6379                |
| `AWS_LB_DNS`             | DNS name of the ALB for WordPress site URL             | Yes      | -                   |
| `WP_TITLE`               | Title for the WordPress site                           | Yes      | -                   |
| `HEALTHCHECK_CONTENT_B64`| Base64-encoded content for healthcheck.php             | No       | Simple 200 response |

The script retrieves the following secrets from AWS Secrets Manager:
- `db_name`: Database name
- `db_username`: Database username
- `db_password`: Database password
- `admin_user`: WordPress admin username
- `admin_email`: WordPress admin email
- `admin_password`: WordPress admin password

### WordPress Deployment Flow

```mermaid
graph TD
    %% Main Components
    A["Start"] --> B["deploy_wordpress.sh"]
    B --> B1["Install PHP, Nginx,<br>WP-CLI"]
    B1 --> B2["Fetch Secrets from<br>AWS Secrets Manager"]
    B2 --> B3["Configure<br>wp-config.php"]
    B3 --> B4["Install WordPress"]
    B4 --> B5["Configure RDS<br>MySQL Connection"]
    B5 --> B6["Configure Redis<br>(ElastiCache)"]
    B6 --> B7["Configure ALB<br>Site URL"]
    B7 --> C["Deployment<br>Completed"]

    %% Server Status Check Flow
    A --> D["check_server_status.sh"]
    D --> D1["Check Instance<br>Metadata"]
    D1 --> D2["Check CPU, Memory,<br>Disk Usage"]
    D2 --> D3["Check Nginx &<br>PHP-FPM Status"]
    D3 --> D4["Check RDS MySQL<br>TLS Connection"]
    D4 --> D5["Check Redis<br>TCP Connection"]
    D5 --> D6["Check ALB DNS /<br>HTTP 200"]
    D6 --> D7["Check WordPress<br>Health"]
    D7 --> D8["Check Nginx<br>Config Syntax"]
    D8 --> E["Server Check<br>Completed"]

    %% AWS Resources Check Flow
    A --> F["check_aws_resources.sh"]
    F --> F1["Check VPC / Subnets /<br>Routes"]
    F1 --> F2["Check EC2 / ASG /<br>EBS"]
    F2 --> F3["Check ALB / TG /<br>Listeners"]
    F3 --> F4["Check RDS / ElastiCache /<br>DynamoDB"]
    F4 --> F5["Check CloudWatch /<br>KMS / WAF / SNS"]
    F5 --> G["AWS Resource<br>Check Completed"]

    %% Healthcheck Files
    B --> H["healthcheck-1.0.php<br>Simple ALB 200 OK"]
    B --> I["healthcheck-2.0.php<br>Full WP API Check"]

    %% Styling
    classDef start fill:#FF9900,stroke:#232F3E,color:white
    classDef deploy fill:#1E8449,stroke:#232F3E,color:white
    classDef status fill:#0066CC,stroke:#232F3E,color:white
    classDef aws fill:#7D3C98,stroke:#232F3E,color:white
    classDef health fill:#DD3522,stroke:#232F3E,color:white
    classDef complete fill:#3F8624,stroke:#232F3E,color:white
    
    class A start
    class B,B1,B2,B3,B4,B5,B6,B7 deploy
    class D,D1,D2,D3,D4,D5,D6,D7,D8 status
    class F,F1,F2,F3,F4,F5 aws
    class H,I health
    class C,E,G complete
```

### check_server_status.sh

Automatically detects:
- Instance metadata (ID, type, availability zone, public IP)
- Resource usage (CPU, memory, disk)
- Service status (Nginx, PHP-FPM)
- Database connectivity with TLS (RDS) from WordPress configuration
- ElastiCache Redis connectivity (TCP + optional PING)
- ALB (Application Load Balancer) DNS reachability
- WordPress integrity and site URL configuration

### check_aws_resources.sh

This script uses AWS CLI credentials and doesn't require additional parameters.

## Usage Instructions

### Deploying WordPress

The `deploy_wordpress.sh` script is typically executed via EC2 user data or Systems Manager. It requires environment variables to be set:

```bash
# Example usage with environment variables
export DB_HOST="your-rds-endpoint.amazonaws.com" # Dynamically assigned by Terraform
export DB_PORT="3306" # Typically MySQL default port
export SECRET_NAME="wordpress/credentials" # Must match Secrets Manager entry
export PHP_VERSION="8.3" # Set PHP version manually
export REDIS_HOST="your-redis-endpoint.amazonaws.com" # Dynamically assigned by Terraform
export REDIS_PORT="6379" # Default Redis port
export AWS_LB_DNS="your-alb-dns.elb.amazonaws.com" # ALB DNS assigned dynamically
export WP_TITLE="My WordPress Site" # Custom site title
sudo -E ./deploy_wordpress.sh
```

### Checking Server Status

The server status check performs:
- TLS-secured RDS connectivity check
- Redis availability check
- ALB health check via HTTP status

```bash
# Run directly on the EC2 instance
sudo ./check_server_status.sh
```

### Monitoring Features (Available in check_server_status.sh v1.0.0+)

- TLS-enforced RDS connectivity check
- Redis availability check (TCP connection + optional PING)
- Application Load Balancer (ALB) DNS reachability and HTTP 200 status verification
- Resource usage monitoring with alert thresholds (CPU, Memory, Disk)

### Example Redis Check (inside check_server_status.sh)

```bash
redis-cli -h $REDIS_HOST -p $REDIS_PORT ping
```

### Checking AWS Resources

```bash
# Run from a machine with AWS CLI configured
./check_aws_resources.sh
```

## Troubleshooting

### Common Issues with WordPress Deployment

1. **Database Connection Failures**
   - Verify security group rules allow traffic from EC2 to RDS
   - Check that the DB_HOST and DB_PORT are correct
   - Ensure the database credentials in Secrets Manager are valid

2. **Redis Connection Issues**
   - Verify security group rules allow traffic from EC2 to ElastiCache
   - Redis runs without TLS (port 6379). Verify connection and Security Group rules.
   - Ensure the REDIS_HOST and REDIS_PORT are correct

3. **WordPress Configuration Problems**
   - Check /var/log/wordpress_install.log for detailed error messages
   - Verify that all required environment variables are set
   - Ensure the WordPress site URL is correctly configured

### Debugging Tips

1. **For deploy_wordpress.sh issues:**
   - Check the log file: `cat /var/log/wordpress_install.log`
   - Verify AWS CLI credentials: `aws sts get-caller-identity`
   - Test database connectivity: `mysql -h $DB_HOST -u $DB_USERNAME -p$DB_PASSWORD -e "SELECT 1;"`

2. **For check_server_status.sh issues:**
   - Manually verify service status: `systemctl status nginx php8.3-fpm`
   - Check WordPress configuration: `cat /var/www/html/wordpress/wp-config.php`
   - Test Redis connectivity: `redis-cli -h $REDIS_HOST -p $REDIS_PORT ping`

3. **For check_aws_resources.sh issues:**
   - Verify AWS CLI installation: `aws --version`
   - Check AWS credentials: `aws configure list`
   - Run individual AWS CLI commands to debug specific resource checks

## Documentation

### Tools and Modules Justification

- **AWS CLI**: Essential for retrieving secrets securely and managing AWS resources programmatically.
- **Terraform Modules**: Provide consistent, repeatable infrastructure deployment.
- **WP-CLI**: Simplifies automated WordPress management tasks.

## Security Considerations

- The scripts handle sensitive information (database credentials, WordPress admin passwords)
- All credentials are retrieved from AWS Secrets Manager rather than being hardcoded
- File permissions are set to restrict access to sensitive files
- TLS is enforced for RDS MySQL connections
- Redis is accessed over plain TCP (port 6379), no TLS configured

## Best Practices

1. Always run the scripts with appropriate permissions (sudo when required)
2. Keep AWS CLI and dependencies updated
3. Review logs after deployment for any warnings or errors
4. Run health checks regularly to ensure system stability
5. Customize the healthcheck scripts based on specific monitoring requirements