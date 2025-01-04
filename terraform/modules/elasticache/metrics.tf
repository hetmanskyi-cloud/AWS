# --- CloudWatch Alarms for Redis --- #

# --- Critical Alarm for Freeable Memory --- #
# This alarm ensures system stability by monitoring free memory.
resource "aws_cloudwatch_metric_alarm" "redis_low_memory" {
  count               = var.enable_redis_low_memory_alarm ? 1 : 0
  alarm_name          = "${var.name_prefix}-redis-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_memory_threshold # Configurable threshold
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
}

# --- High CPU Utilization Alarm --- #
# Monitors CPU usage to detect performance issues.
resource "aws_cloudwatch_metric_alarm" "redis_high_cpu" {
  count               = var.enable_redis_high_cpu_alarm ? 1 : 0
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

# --- CPU Credit Balance Alarm --- #
# This alarm monitors CPU credit balance for burstable instance types (e.g., cache.t3.micro).
# If CPU credits drop too low, performance may degrade due to throttling.
resource "aws_cloudwatch_metric_alarm" "redis_low_cpu_credits" {
  count               = var.enable_redis_low_cpu_credits_alarm ? 1 : 0
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

# --- Notes --- #
# 1. Monitoring strategy:
#    - Critical alarms are controlled via dedicated enable variables:
#       - `enable_redis_low_memory_alarm` for memory monitoring.
#       - `enable_redis_high_cpu_alarm` for CPU utilization.
#       - `enable_redis_low_cpu_credits_alarm` for CPU credits.
# 2. The 'redis_low_cpu_credits' alarm prevents performance degradation by ensuring sufficient CPU credits are available.
#    This is particularly critical for burstable instance types.
# 3. All alarm thresholds are fully configurable through input variables for flexibility.
# 4. Use CloudWatch Alarms to detect and address resource bottlenecks early, improving reliability and availability.