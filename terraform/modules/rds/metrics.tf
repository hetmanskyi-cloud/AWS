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
  alarm_actions = [
    var.sns_topic_arn,                          # Notify via SNS topic
    aws_lambda_function.create_read_replica.arn # Trigger Lambda to create a read replica
  ]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier # Dimension specifies the RDS instance
  }
}

# Alarm for low CPU utilization
# Triggers an alarm when the average CPU utilization drops below the defined threshold
# Used for deleting replicas when CPU usage is low
resource "aws_cloudwatch_metric_alarm" "rds_low_cpu_utilization" {
  alarm_name          = "${var.name_prefix}-rds-low-cpu"
  comparison_operator = "LessThanThreshold" # Alarm triggers when value is below the threshold
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold_low # Low CPU utilization threshold from variables
  alarm_actions = [
    var.sns_topic_arn,                          # Notify via SNS topic
    aws_lambda_function.delete_read_replica.arn # Trigger Lambda to delete a read replica
  ]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
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
# Optional alarm to monitor the number of active database connections
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold" # Alarm triggers when value exceeds the threshold
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections" # Metric being monitored
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold # High connection threshold from variables
  alarm_actions       = []                            # No action defined; only logs the alarm
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}
