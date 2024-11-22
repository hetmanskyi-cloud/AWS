# --- CloudWatch Alarms for Redis --- #

# Alarm for high CPU usage
resource "aws_cloudwatch_metric_alarm" "redis_high_cpu" {
  alarm_name          = "${var.name_prefix}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3 # Increased evaluation periods to reduce false positives
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300 # 5 minutes interval
  statistic           = "Average"
  threshold           = var.redis_cpu_threshold
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
}

# Alarm for low free memory
resource "aws_cloudwatch_metric_alarm" "redis_low_memory" {
  alarm_name          = "${var.name_prefix}-redis-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_memory_threshold
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_low_cpu_credits" {
  alarm_name          = "${var.name_prefix}-redis-low-cpu-credits"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 5 # Alarm triggers if CPU credits fall below 5
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
}
