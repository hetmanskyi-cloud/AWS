# --- CloudWatch Alarms for RDS --- #

# Alarm for high CPU utilization
# Triggers an alarm when the average CPU utilization exceeds the defined threshold
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu_utilization" {
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

# Alarm for low free storage space
# Triggers an alarm when the available storage space falls below the threshold
resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  alarm_name          = "${var.name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold" # Alarm triggers when value is below the threshold
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_storage_threshold # Low storage space threshold from variables
  alarm_actions       = [var.sns_topic_arn]       # Notify via SNS topic
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}

# Alarm for high number of database connections
# Monitors the number of active database connections
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold" # Alarm triggers when value exceeds the threshold
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections" # Metric being monitored
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold # High connection threshold from variables
  alarm_actions       = [var.sns_topic_arn]           # Notify via SNS topic
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}
