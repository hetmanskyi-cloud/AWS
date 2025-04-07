# --- CloudWatch Logs Configuration --- #
# This file defines centralized logging for the WordPress infrastructure

# --- Log Group: EC2 user-data script --- #
# Captures provisioning logs from EC2 user_data.
# Used for debugging install errors (AWS CLI, Nginx, PHP, WordPress).
# Log stream pattern: {instance_id}
resource "aws_cloudwatch_log_group" "user_data_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/user-data"   # Log group name used in cloudwatch agent config
  retention_in_days = 7                      # Retain logs for 7 days to reduce cost for dev/stage  
  kms_key_id        = module.kms.kms_key_arn # Enables CMK-based encryption
  skip_destroy      = false                  # Log group will be destroyed with terraform destroy

  tags = {
    Name        = "${var.name_prefix}-user-data-logs"
    Environment = var.environment
  }
}

# --- Log Group: EC2 system logs --- #
# Captures OS-level logs (/var/log/syslog or /var/log/messages).
# Useful for SSH activity, kernel issues, or cron jobs
resource "aws_cloudwatch_log_group" "system_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/system"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = {
    Name        = "${var.name_prefix}-system-logs"
    Environment = var.environment
  }
}

# --- Log Group: Nginx logs --- #
# Captures access and error logs from Nginx.
# Useful for monitoring HTTP traffic and 5xx/4xx errors.
resource "aws_cloudwatch_log_group" "nginx_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/nginx"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = {
    Name        = "${var.name_prefix}-nginx-logs"
    Environment = var.environment
  }
}

# --- Log Group: PHP-FPM logs --- #
# Captures logs from PHP FastCGI Process Manager.
# Used to detect PHP worker crashes or syntax errors.
resource "aws_cloudwatch_log_group" "php_fpm_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/php-fpm"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = {
    Name        = "${var.name_prefix}-php-fpm-logs"
    Environment = var.environment
  }
}

# --- Log Group: WordPress logs --- #
# Captures WP_DEBUG or plugin logs written to /var/log/wordpress.log.
# Must be enabled manually in wp-config.php.
resource "aws_cloudwatch_log_group" "wordpress_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/wordpress"
  retention_in_days = var.cw_logs_retention_in_days
  kms_key_id        = module.kms.kms_key_arn
  skip_destroy      = false

  tags = {
    Name        = "${var.name_prefix}-wordpress-logs"
    Environment = var.environment
  }
}

# --- Metric Filter: Nginx 5xx errors --- #
# Triggers metric when log contains HTTP 5xx codes (500–599).
# - Useful for identifying backend application failures or Nginx misconfigurations.
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

# --- Alarm: Nginx 5xx threshold --- #
# Triggers when 5+ errors occur within 5 minutes.
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
}

# --- Metric Filter: PHP fatal errors --- #
# Detects "PHP Fatal error" entries in WordPress logs.
# - Helps detect issues like missing dependencies, broken code, or plugin conflicts.
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

# --- Alarm: PHP fatal error threshold --- #
# Triggers if more than 2 fatal errors occur in 5 minutes.
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
}

# --- Notes --- #
# - This module enables centralized logging for EC2 instances running WordPress.
# - Each log group is encrypted using a KMS CMK (Customer Managed Key) from the KMS module.
# - Logging can be toggled using `enable_cloudwatch_logs = true` in terraform.tfvars.
# - All log groups are configured with retention to reduce cost in non-prod environments.
# - Alarms send notifications to an SNS topic (cloudwatch_alarms) configured elsewhere.
# - WordPress logs require WP_DEBUG and custom log redirection to /var/log/wordpress.log.
# - For production, adjust `retention_in_days` as needed and fine-tune alarm thresholds.