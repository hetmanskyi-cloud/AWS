# --- CloudWatch Alarms for RDS --- #
# CloudWatch alarms can be enabled or disabled using the enable_<alarm> variables.
# This flexibility allows monitoring to be adjusted for testing or production environments.

# --- Low Free Storage Space Alarm --- #
# Monitors available storage space and triggers an alarm if exceeded.
resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  count = var.enable_low_storage_alarm ? 1 : 0 # Controlled via enable_low_storage_alarm variable

  alarm_name                = "${var.name_prefix}-rds-low-storage-${var.environment}"
  comparison_operator       = "LessThanThreshold" # Alarm triggers when value is below the threshold
  evaluation_periods        = 1
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.rds_storage_threshold # Storage threshold from variables
  alarm_actions             = [var.sns_topic_arn]
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Dimension specifies the RDS instance
  }
  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- High CPU Utilization Alarm --- #
# Monitors CPU usage and triggers an alarm when it exceeds the defined threshold.
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu_utilization" {
  count = var.enable_high_cpu_alarm ? 1 : 0 # Controlled via enable_high_cpu_alarm variable

  alarm_name                = "${var.name_prefix}-rds-high-cpu-${var.environment}"
  comparison_operator       = "GreaterThanThreshold"     # Alarm triggers when value exceeds the threshold
  evaluation_periods        = 2                          # Number of evaluation periods for alarm
  metric_name               = "CPUUtilization"           # Metric being monitored
  namespace                 = "AWS/RDS"                  # Namespace for RDS metrics
  period                    = 300                        # Evaluation period in seconds
  statistic                 = "Average"                  # Use average metric for alarm
  threshold                 = var.rds_cpu_threshold_high # High CPU utilization threshold from variables
  alarm_actions             = [var.sns_topic_arn]        # Notify via SNS topic
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Dimension specifies the RDS instance
  }
  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- High Number of Database Connections --- #
# Monitors the number of active database connections and triggers an alarm if exceeded.
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  count = var.enable_high_connections_alarm ? 1 : 0 # Controlled via enable_high_connections_alarm variable

  alarm_name                = "${var.name_prefix}-rds-high-connections-${var.environment}"
  comparison_operator       = "GreaterThanThreshold" # Alarm triggers when value exceeds the threshold
  evaluation_periods        = 1
  metric_name               = "DatabaseConnections"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.rds_connections_threshold # High connection threshold from variables
  alarm_actions             = [var.sns_topic_arn]           # Notify via SNS topic
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Dimension specifies the RDS instance
  }
  # Ensure the RDS instance is created before the alarm
  depends_on = [aws_db_instance.db]
}

# --- Notes --- #
# 1. Alarms are controlled via `enable_<alarm>` variables to allow granular configuration.
# 2. Thresholds for storage, CPU utilization, and connections are customizable.
# 3. Alarms ensure early detection of performance issues for RDS instances.