# --- CloudWatch Alarms for RDS --- #

# Alarm for high CPU utilization
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu_utilization" {
  alarm_name          = "${var.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold_high
  alarm_actions = [
    var.sns_topic_arn,                          # SNS topic for notifications
    aws_lambda_function.create_read_replica.arn # Lambda for creating replica
  ]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.id
  }
}

# Alarm for low CPU utilization (delete replica)
resource "aws_cloudwatch_metric_alarm" "rds_low_cpu_utilization" {
  alarm_name          = "${var.name_prefix}-rds-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold_low
  alarm_actions = [
    var.sns_topic_arn,                         # SNS topic for notifications
  aws_lambda_function.delete_read_replica.arn] # Lambda for deleting replica
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.id
  }
}

# Alarm for low free storage space
resource "aws_cloudwatch_metric_alarm" "rds_low_free_storage" {
  alarm_name          = "${var.name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_storage_threshold
  alarm_actions       = [var.sns_topic_arn] # SNS topic for notifications
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.id
  }
}

# Alarm for high number of database connections (optional)
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.name_prefix}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  alarm_actions       = [] # Alarm without action
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.id
  }
}
