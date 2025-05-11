# --- CloudWatch Logs Configuration for WordPress infrastructure --- #
# Enables centralized log management and metric-based alerting.
# Log groups are encrypted using KMS CMK and auto-cleaned up in non-prod.

# --- Log Group: EC2 user-data script --- #
# Captures logs from EC2 user_data provisioning script.
# Used for debugging setup issues (e.g., AWS CLI, Nginx, PHP, WordPress).
resource "aws_cloudwatch_log_group" "user_data_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/user-data"
  retention_in_days = var.cw_logs_retention_in_days # Short retention for dev/stage environments
  kms_key_id        = module.kms.kms_key_arn        # Encrypt logs using CMK
  skip_destroy      = false                         # Destroy with terraform destroy

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-user-data-logs"
  })
}

# --- Log Group: EC2 system logs --- #
# Captures OS-level logs such as /var/log/syslog or /var/log/messages.
# Useful for monitoring SSH activity, cron jobs, kernel issues, etc.
resource "aws_cloudwatch_log_group" "system_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/system"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-system-logs"
  })
}

# --- Log Group: Nginx access and error logs --- #
# Collects access and error logs from the Nginx web server.
# Helps monitor HTTP traffic, 5xx/4xx response codes, and routing issues.
resource "aws_cloudwatch_log_group" "nginx_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/nginx"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-nginx-logs"
  })
}

# --- Log Group: PHP-FPM logs --- #
# Collects PHP FastCGI Process Manager logs.
# Useful for identifying PHP syntax errors, worker crashes, etc.
resource "aws_cloudwatch_log_group" "php_fpm_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/php-fpm"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-php-fpm-logs"
  })
}

# --- Log Group: WordPress logs --- #
# Captures logs written to /var/log/wordpress.log (custom WP_DEBUG).
# Requires manual setup in wp-config.php to enable logging.
resource "aws_cloudwatch_log_group" "wordpress_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/wordpress"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-wordpress-logs"
  })
}

# --- Metric Filter: Nginx 5xx Errors --- #
# Filters for HTTP 5xx response codes in Nginx logs.
# Helps detect backend application or Nginx configuration issues.
resource "aws_cloudwatch_log_metric_filter" "nginx_5xx_errors" {
  count          = var.enable_cloudwatch_logs ? 1 : 0
  name           = "${var.name_prefix}-nginx-5xx-errors"
  log_group_name = aws_cloudwatch_log_group.nginx_logs[0].name
  pattern        = "[ip, identity, user, timestamp, request, status_code=5*, size, ...]"

  metric_transformation {
    name      = "nginx5xxErrorCount"
    namespace = "WordPress/Nginx"
    value     = "1"
  }
}

# --- CloudWatch Alarm: Nginx 5xx Errors --- #
# Triggers alarm if more than 5 errors occur within 5 minutes.
resource "aws_cloudwatch_metric_alarm" "nginx_5xx_alarm" {
  count               = var.enable_cloudwatch_logs ? 1 : 0
  alarm_name          = "${var.name_prefix}-nginx-5xx-error-alarm"
  alarm_description   = "Triggers when Nginx 5xx errors exceed 5 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  metric_name         = "nginx5xxErrorCount"
  namespace           = "WordPress/Nginx"
  period              = 300
  statistic           = "Sum"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  depends_on = [aws_sns_topic.cloudwatch_alarms]

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-nginx-5xx-error-alarm"
  })
}

# --- Metric Filter: PHP Fatal Errors --- #
# Detects "PHP Fatal error" entries in WordPress logs.
# Used to catch plugin failures, syntax issues, and runtime crashes.
resource "aws_cloudwatch_log_metric_filter" "php_fatal_errors" {
  count          = var.enable_cloudwatch_logs ? 1 : 0
  name           = "${var.name_prefix}-php-fatal-errors"
  log_group_name = aws_cloudwatch_log_group.wordpress_logs[0].name
  pattern        = "PHP Fatal error"

  metric_transformation {
    name      = "phpFatalErrorCount"
    namespace = "WordPress/PHP"
    value     = "1"
  }
}

# --- CloudWatch Alarm: PHP Fatal Errors --- #
# Triggers alarm if more than 2 fatal errors occur within 5 minutes.
resource "aws_cloudwatch_metric_alarm" "php_fatal_alarm" {
  count               = var.enable_cloudwatch_logs ? 1 : 0
  alarm_name          = "${var.name_prefix}-php-fatal-error-alarm"
  alarm_description   = "Triggers when PHP Fatal errors exceed 2 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2
  metric_name         = "phpFatalErrorCount"
  namespace           = "WordPress/PHP"
  period              = 300
  statistic           = "Sum"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  depends_on = [aws_sns_topic.cloudwatch_alarms]

  tags = merge(local.tags_cloudwatch, {
    Name = "${var.name_prefix}-php-fatal-error-alarm"
  })
}

# --- Notes --- #
# 1. Log Groups:
#    - Logs are collected from EC2, Nginx, PHP-FPM, and WordPress runtime
#    - Each group uses CMK encryption (via KMS module)
#    - Retention can be adjusted per environment via terraform.tfvars
#
# 2. Metric Filters:
#    - Custom patterns detect Nginx 5xx and PHP fatal errors
#    - Metrics are created per pattern and published to custom namespaces
#
# 3. Alarms:
#    - Alarms send notifications via SNS (configured separately)
#    - Thresholds can be fine-tuned per environment or workload
#
# 4. Control Flags:
#    - Use `enable_cloudwatch_logs = true` in terraform.tfvars to enable
#    - Set `cw_logs_retention_in_days` to control log lifecycle
#
# 5. Best Practices:
#    - All logs are centralized for easier monitoring and debugging
#    - Use alarms in combination with Auto Scaling health checks
#
# 6. Encryption and Cleanup:
#    - All log groups are encrypted using Customer Managed KMS Key (CMK)
#    - `skip_destroy = false` allows safe cleanup during `terraform destroy` in non-prod
#
# 7. Integration with Other Modules:
#    - Alarms and logs work in tandem with ASG, ALB, and RDS monitoring configurations
#    - ALB logs are captured via access logs to S3 (enabled in the ALB module)
#    - RDS exports `error` and `slowquery` logs to CloudWatch
#    - VPC Flow Logs are configured in the VPC module and monitored for delivery issues
#
# 8. Design Justification:
#    - This CloudWatch configuration includes the **minimum required log groups and alarms** for WordPress on EC2 to ensure visibility, debuggability, and security.
#    - We intentionally excluded overly verbose log groups (e.g., all `/var/log/*`) to reduce cost and noise.
#
#    - Log groups:
#      - `/aws/ec2/user-data`: Captures provisioning logs (critical during initial setup)
#      - `/aws/ec2/system`: Captures OS-level logs for debugging and SSH access issues
#      - `/aws/ec2/nginx`: Monitors web server access and error logs
#      - `/aws/ec2/php-fpm`: Helps detect PHP-level issues
#      - `/aws/ec2/wordpress`: Application-specific logs (must be enabled via `wp-config.php`)
#
#    - Metric filters and alarms:
#      - Focused only on 5xx errors (from Nginx) and PHP Fatal Errors — two key signals of application failure.
#      - These are directly actionable and correlated with actual user-facing errors.
#      - Other types of application metrics (e.g., high traffic, slow responses) are already handled in the **ALB module** via access logs and CloudWatch metrics.
#    - Although we already have an ALB 5xx alarm (`HTTPCode_Target_5XX_Count` in the ALB module),
#      we also monitor 5xx responses directly from Nginx logs via metric filter:
#        - **ALB 5xx** provides high-level infrastructure monitoring for ASG targets.
#        - **Nginx 5xx** provides application-layer details (URL, IP, exact code) directly from access logs.
#        - Together, they create a **multi-layered alerting system** for faster diagnosis and deeper visibility.
#
#    - ALB access logs are already enabled in the ALB module and exported to S3 for further analysis.
#    - Additional metrics for infrastructure and backend (e.g., RDS, Redis, ASG, VPC Flow Logs) are covered in their respective modules to avoid duplication and maintain modularity.
#
#    - This configuration provides:
#      - **Sufficient visibility** to troubleshoot most WordPress issues.
#      - **Low operational cost** for development and staging environments.
#      - **Scalable structure**, where deeper monitoring can be added per module if needed.
#      - **Modularity**, ensuring each module owns its own metrics and alarms cleanly.