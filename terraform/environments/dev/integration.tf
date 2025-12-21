# --- Dedicated Notification for WordPress Media Bucket --- #
resource "aws_s3_bucket_notification" "wordpress_media_unified_notification" {
  # This dedicated resource manages ALL notifications for the wordpress_media bucket.
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  bucket = module.s3.wordpress_media_bucket_name

  # SQS Notification for Image Processing.
  queue {
    queue_arn     = module.sqs[0].queue_arns["image-processing"]
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = var.wordpress_media_uploads_prefix
  }

  # SNS Notification for General Purpose.
  topic {
    topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn
    events    = ["s3:ObjectRemoved:*"]
  }

  # This explicit dependency ensures that the SQS queue policy is attached
  # BEFORE S3 tries to validate the notification destination.
  depends_on = [
    aws_sqs_queue_policy.wordpress_media_s3_policy,
  module.s3]
}

# --- SQS Queue Policy for S3 Notifications --- #
# This data source and resource pair creates and attaches a policy to the SQS queue.
data "aws_iam_policy_document" "sqs_policy_for_s3" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  statement {
    sid       = "AllowS3ToSendMessageToSQS"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs[0].queue_arns["image-processing"]]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    # This condition ensures only our specific S3 bucket can send messages.
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.s3.wordpress_media_bucket_arn]
    }
  }
}

# SQS Queue Policy for WordPress Media Bucket
resource "aws_sqs_queue_policy" "wordpress_media_s3_policy" {
  count = var.enable_image_processor && try(var.default_region_buckets["wordpress_media"].enabled, false) ? 1 : 0

  queue_url = module.sqs[0].queue_urls["image-processing"]
  policy    = data.aws_iam_policy_document.sqs_policy_for_s3[0].json
}

# --- WAF IP Set Updater for Client VPN --- #
# This data source runs an external script to fetch the dynamic egress IPs of the Client VPN.
# It provides a clean, declarative way to bring external data into Terraform.

data "external" "vpn_egress_ips" {
  # Run only if both Client VPN and CloudFront WAF are enabled.
  count = var.enable_client_vpn && var.enable_cloudfront_waf ? 1 : 0

  program = ["bash", "${path.root}/../../scripts/get_vpn_ips.sh"]

  # Pass input to the script as a JSON object.
  query = {
    vpn_endpoint_id = module.client_vpn[0].client_vpn_endpoint_id
    region          = var.aws_region # Pass the region where the VPN is deployed
  }

  depends_on = [module.client_vpn]
}

# --- Notes --- #
# - This file manages cross-module integrations and external data sources for the environment.
# - S3 Notifications: Configures a unified notification for the 'wordpress_media' bucket, sending events to SQS (for image processing) and SNS (for monitoring).
# - Dependency Management: Uses explicit `depends_on` to ensure SQS policies are in place before S3 attempts to configure notifications.
# - External Data: Employs a 'get_vpn_ips.sh' script to dynamically retrieve Client VPN egress IPs for WAF whitelisting.
