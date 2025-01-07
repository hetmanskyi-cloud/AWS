resource "aws_cloudtrail" "this" {
  count = var.enable_logging ? 1 : 0

  name                          = "${var.name_prefix}-cloudtrail-${var.environment}"
  s3_bucket_name                = var.s3_bucket_arn
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.multi_region_trail
  enable_log_file_validation    = var.log_file_validation_enabled
  enable_logging                = var.enable_logging

  # Use KMS key if provided
  kms_key_id = var.kms_key_arn != null ? var.kms_key_arn : null

  # Use SNS topic if provided
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::KMS::Key"
      values = ["*"] # Можно уточнить конкретные ключи, если необходимо
    }
  }

  tags = {
    Name        = "${var.name_prefix}-cloudtrail-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudtrail_event_selector" "kms_specific" {
  count = var.enable_logging ? 1 : 0

  trail_name = aws_cloudtrail.this[0].name

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::KMS::Key"
      values = ["*"] # Или конкретные ARNs ключей
    }
  }
}

resource "aws_cloudtrail_sns_topic_association" "this" {
  count = var.sns_topic_arn != null && var.enable_logging ? 1 : 0

  trail_name    = aws_cloudtrail.this[0].name
  sns_topic_arn = var.sns_topic_arn
}
