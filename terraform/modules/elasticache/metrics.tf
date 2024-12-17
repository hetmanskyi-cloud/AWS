# --- CloudWatch Alarms for Redis --- #

# --- Critical Alarm for Freeable Memory (dev) --- #
# This alarm ensures system stability by monitoring free memory in dev environments.
resource "aws_cloudwatch_metric_alarm" "redis_low_memory" {
  count               = var.environment == "dev" ? 1 : 0
  alarm_name          = "${var.name_prefix}-redis-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_memory_threshold / 2 # Less strict threshold for dev
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }
}

# --- High CPU Utilization Alarm (stage/prod) --- #
# Monitors CPU usage to detect performance issues in stage and production environments.
resource "aws_cloudwatch_metric_alarm" "redis_high_cpu" {
  count               = var.environment != "dev" ? 1 : 0
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

# --- CPU Credit Balance Alarm (stage/prod) --- #
# This alarm monitors CPU credit balance for burstable instance types (e.g., cache.t3.micro).
# If CPU credits drop too low, performance may degrade due to throttling.
resource "aws_cloudwatch_metric_alarm" "redis_low_cpu_credits" {
  count               = var.environment != "dev" ? 1 : 0
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
#    - 'dev': Includes only critical alarms (e.g., FreeableMemory) with less strict thresholds to minimize noise and cost.
#             Example: FreeableMemory threshold is reduced to half for dev environments.
#    - 'stage'/'prod': Full monitoring is enabled, including:
#       - CPU Utilization (redis_high_cpu) to detect performance issues.
#       - CPU Credit Balance (redis_low_cpu_credits) for burstable instances (e.g., cache.t3.micro).
# 2. The 'redis_low_cpu_credits' alarm prevents performance degradation by ensuring sufficient CPU credits are available.
#    This is particularly critical for burstable instance types.
# 3. All alarm thresholds are fully configurable through input variables for flexibility.
# 4. Use CloudWatch Alarms to detect and address resource bottlenecks early, improving reliability and availability.