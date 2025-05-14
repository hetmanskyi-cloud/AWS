# --- CloudWatch Alarms for Redis --- #

# --- Critical Alarm for Freeable Memory --- #
# This alarm ensures system stability by monitoring free memory.
resource "aws_cloudwatch_metric_alarm" "redis_low_memory" {
  count                     = var.enable_redis_low_memory_alarm ? 1 : 0
  alarm_name                = "${var.name_prefix}-redis-low-memory"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/ElastiCache"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.redis_memory_threshold # Configurable threshold
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-redis-low-memory-${var.environment}"
    AlertType = "Redis:FreeableMemory"
    Type      = "Memory"
  })
}

# --- High CPU Utilization Alarm --- #
# Monitors CPU usage. Uses 3 evaluation periods to reduce false alarms
# from temporary CPU spikes which are normal for Redis operations.
resource "aws_cloudwatch_metric_alarm" "redis_high_cpu" {
  count                     = var.enable_redis_high_cpu_alarm ? 1 : 0
  alarm_name                = "${var.name_prefix}-redis-high-cpu"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 3 # Increased evaluation periods to reduce false positives
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ElastiCache"
  period                    = 300 # 5 minutes interval
  statistic                 = "Average"
  threshold                 = var.redis_cpu_threshold
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-redis-high-cpu-${var.environment}"
    AlertType = "Redis:CPUUtilization"
    Type      = "CPU"
  })
}

# --- Replication Bytes Used Alarm --- #
# Monitors the replication bytes used to detect high memory usage for replication.
# This metric is only relevant when replicas are configured.
resource "aws_cloudwatch_metric_alarm" "redis_replication_bytes_used" {
  count = var.enable_redis_replication_bytes_alarm && var.replicas_per_node_group > 0 ? 1 : 0

  alarm_name                = "${var.name_prefix}-redis-replication-bytes-used"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "ReplicationBytesUsed"
  namespace                 = "AWS/ElastiCache"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.redis_replication_bytes_threshold # Configurable threshold
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-redis-replication-bytes-used-${var.environment}"
    AlertType = "Redis:ReplicationBytesUsed"
    Type      = "Replication"
  })
}

# --- CPU Credit Balance Alarm --- #
# Monitors CPU credit balance for burstable instances to prevent throttling.
resource "aws_cloudwatch_metric_alarm" "redis_low_cpu_credits" {
  count                     = var.enable_redis_low_cpu_credits_alarm ? 1 : 0
  alarm_name                = "${var.name_prefix}-redis-low-cpu-credits"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUCreditBalance"
  namespace                 = "AWS/ElastiCache"
  period                    = 300
  statistic                 = "Average"
  threshold                 = var.redis_cpu_credits_threshold # Default can be 5
  alarm_actions             = [var.sns_topic_arn]
  ok_actions                = [var.sns_topic_arn]
  insufficient_data_actions = [var.sns_topic_arn]
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-redis-low-cpu-credits-${var.environment}"
    AlertType = "Redis:CPUCreditBalance"
    Type      = "CPU Credits"
  })
}

# --- Notes --- #
# 1. Monitoring strategy:
#    - Critical alarms are controlled via enable variables:
#       - `enable_redis_low_memory_alarm`: Monitors memory usage to prevent bottlenecks.
#       - `enable_redis_high_cpu_alarm`: Tracks CPU utilization for performance issues.#       
#       - `enable_redis_replication_bytes_alarm`: Tracks replication memory usage to detect potential issues with replication memory overhead.
#       - `enable_redis_low_cpu_credits_alarm`: Ensures sufficient CPU credits for burstable instance types.
# 2. Alarms help detect and resolve resource bottlenecks early, improving reliability and availability.
# 3. Configurable thresholds and enable variables provide flexibility across environments.