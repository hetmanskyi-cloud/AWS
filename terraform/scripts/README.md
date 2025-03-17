# AWS WordPress Deployment Scripts

This directory contains scripts used for deploying, checking, and maintaining WordPress installations on AWS infrastructure. These scripts are designed to work with the Terraform modules in this project.

## Scripts Overview

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

### check_server_status.sh

Automatically detects:
- Instance metadata (ID, type, availability zone, public IP)
- Resource usage (CPU, memory, disk)
- Service status (Nginx, PHP-FPM)
- Database connectivity from WordPress configuration
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

```bash
# Run directly on the EC2 instance
sudo ./check_server_status.sh
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
   - Check that TLS is properly configured if using encryption
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

### Code Structure Overview

```
scripts/
├── check_aws_resources.sh   # Checks AWS resource status
├── check_server_status.sh   # EC2 instance health checker
├── deploy_wordpress.sh      # Automates WordPress deployment
├── healthcheck-1.0.php      # Simple ALB health check
└── healthcheck-2.0.php      # Advanced ALB health check
```

## Security Considerations

- The scripts handle sensitive information (database credentials, WordPress admin passwords)
- All credentials are retrieved from AWS Secrets Manager rather than being hardcoded
- File permissions are set to restrict access to sensitive files
- TLS is used for Redis connections when configured

## Best Practices

1. Always run the scripts with appropriate permissions (sudo when required)
2. Keep AWS CLI and dependencies updated
3. Review logs after deployment for any warnings or errors
4. Run health checks regularly to ensure system stability
5. Customize the healthcheck scripts based on specific monitoring requirements