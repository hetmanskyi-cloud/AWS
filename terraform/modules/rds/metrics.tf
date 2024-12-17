# --- CloudWatch Alarms for RDS --- #

# --- Low Free Storage Space Alarm --- #
# Monitors available storage space and adjusts the threshold based on the environment.
resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  count               = 1 # Enabled in all environments with environment-specific thresholds
  alarm_name          = var.environment == "dev" ? "${var.name_prefix}-rds-low-storage-dev" : "${var.name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold" # Alarm triggers when value is below the threshold
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "dev" ? var.rds_storage_threshold / 2 : var.rds_storage_threshold # Adjust threshold for dev
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}

# --- High CPU Utilization Alarm (Stage/Prod) --- #
# Monitors CPU usage and triggers an alarm when it exceeds the defined threshold.
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu_utilization" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage and prod
  alarm_name          = "${var.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"     # Alarm triggers when value exceeds the threshold
  evaluation_periods  = 2                          # Number of evaluation periods for alarm
  metric_name         = "CPUUtilization"           # Metric being monitored
  namespace           = "AWS/RDS"                  # Namespace for RDS metrics
  period              = 300                        # Evaluation period in seconds
  statistic           = "Average"                  # Use average metric for alarm
  threshold           = var.rds_cpu_threshold_high # High CPU utilization threshold from variables
  alarm_actions       = [var.sns_topic_arn]        # Notify via SNS topic
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Dimension specifies the RDS instance
  }
}

# --- High Number of Database Connections (Stage/Prod) --- #
# Monitors the number of active database connections and triggers an alarm if exceeded.
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  count               = var.environment != "dev" ? 1 : 0 # Enabled only in stage and prod
  alarm_name          = "${var.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold" # Alarm triggers when value exceeds the threshold
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold # High connection threshold from variables
  alarm_actions       = [var.sns_topic_arn]           # Notify via SNS topic
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}

# --- Notes --- #
# 1. The Low Free Storage Space alarm uses environment-specific thresholds:
#    - In 'dev', the threshold is less strict (50% of the production value).
#    - In 'stage' and 'prod', the full threshold is used to detect critical storage issues.
# 2. High CPU Utilization and Database Connections alarms are enabled only in 'stage' and 'prod' to reduce costs in 'dev'.
# 3. Thresholds for CPU, storage, and connections are configurable via input variables.
# 4. CloudWatch alarms ensure early detection of performance bottlenecks and resource issues.