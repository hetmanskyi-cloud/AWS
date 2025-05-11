# --- CloudWatch Alarms for RDS --- #
# Configures CloudWatch alarms for RDS instance monitoring.
# Alarms are conditionally created based on 'enable_<alarm>' variables for flexible deployment (e.g., testing vs. production).

# --- Low Free Storage Space Alarm --- #
# Alarm for low RDS free storage space. Triggers when storage falls below the defined threshold.
resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  count = var.enable_low_storage_alarm ? 1 : 0 # Enable via 'enable_low_storage_alarm' variable.

  alarm_name                = "${var.name_prefix}-rds-low-storage-${var.environment}"
  alarm_description         = "Monitors RDS free storage space. Triggers when available storage is below threshold."
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.rds_storage_threshold # Threshold for low free storage space on RDS (in bytes, e.g., 10 GB = 10737418240)
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [] # Insufficient data actions disabled for test environments.
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Target RDS instance.
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-rds-storage-alarm-${var.environment}"
    Type      = "Storage"
    AlertType = "RDS:FreeStorageSpace"
  })

  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- High CPU Utilization Alarm --- #
# Alarm for high RDS CPU utilization. Triggers when CPU usage exceeds the defined threshold.
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu_utilization" {
  count = var.enable_high_cpu_alarm ? 1 : 0 # Enable via 'enable_high_cpu_alarm' variable.

  alarm_name                = "${var.name_prefix}-rds-high-cpu-${var.environment}"
  alarm_description         = "Monitors RDS CPU utilization. Triggers when CPU usage exceeds threshold."
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2 # Evaluation periods (2 periods for CPU alarm).
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.rds_cpu_threshold_high # High CPU threshold from variable.
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [] # Insufficient data actions disabled for test environments.
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Target RDS instance.
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-rds-cpu-alarm-${var.environment}"
    Type      = "CPU"
    AlertType = "RDS:CPUUtilization"
  })

  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- High Number of Database Connections Alarm --- #
# Alarm for high RDS database connections. Triggers when the number of connections exceeds the threshold.
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  count = var.enable_high_connections_alarm ? 1 : 0 # Enable via 'enable_high_connections_alarm' variable.

  alarm_name                = "${var.name_prefix}-rds-high-connections-${var.environment}"
  alarm_description         = "Monitors RDS database connections. Triggers when connection count exceeds threshold."
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 3 # Evaluation periods (3 periods for connection alarm).
  metric_name               = "DatabaseConnections"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.rds_connections_threshold # High connection threshold from variable.
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [] # Insufficient data actions disabled for test environments.
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Target RDS instance.
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-rds-connections-alarm-${var.environment}"
    Type      = "Connections"
    AlertType = "RDS:DatabaseConnections"
  })

  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- Notes --- #
# 1. Alarms are conditionally enabled via `enable_<alarm>` variables, allowing for granular control over monitoring.
# 2. Thresholds for storage, CPU utilization, and database connections are customizable through variables.
# 3. These alarms facilitate early detection of potential performance bottlenecks and issues for RDS instances.
# 4. 'insufficient_data_actions' are disabled for test environments to minimize alert noise during testing.
# 5. 'evaluation_periods' are adjusted based on metric sensitivity to reduce false positives:
#    - Storage: 1 period (immediate alert for critical storage issues).
#    - CPU Utilization: 2 periods (mitigate false alarms from short CPU spikes).
#    - Database Connections: 3 periods (tolerate temporary connection fluctuations).
# 6. Production Recommendation:
#    - Consider adding additional alarms (e.g., Read IOPS, Write IOPS, Replica Lag) for comprehensive monitoring in production.
# 7. SNS Alarm Behavior:
#    - Alarms trigger actions only if `sns_topic_arn` is provided.
#    - For dev environments, use a placeholder or null action if SNS delivery is not required.
# 8. Extensibility:
#    - Additional alarms (e.g., ReadIOPS, Replica Lag, FreeableMemory) can be added based on production requirements.
#    - Use standardized tag structure (e.g., AlertType) to support automation and tag-based notifications/routing.