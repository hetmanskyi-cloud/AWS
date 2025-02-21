# --- CloudWatch Logs Configuration for VPC Endpoints --- #

# --- CloudWatch Log Group --- #
# Creates a CloudWatch Log Group for monitoring VPC Endpoint traffic.
# Enabled only when 'enable_cloudwatch_logs_for_endpoints' is true.
resource "aws_cloudwatch_log_group" "endpoint_logs" {
  count             = var.enable_cloudwatch_logs_for_endpoints ? 1 : 0
  name              = "/aws/vpc-endpoints/${var.name_prefix}-${var.environment}"
  retention_in_days = var.endpoints_log_retention_in_days # Configurable retention period
  kms_key_id        = var.kms_key_arn                     # KMS key for encryption

  # Note: Ensure 'kms_key_arn' is valid and configured for CloudWatch Logs encryption.
  # If logs are enabled, this resource provides critical monitoring insights for VPC Endpoints.

  tags = {
    Name        = "${var.name_prefix}-endpoint-logs"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. This log group is created only when 'enable_cloudwatch_logs_for_endpoints' is set to true.
# 2. The retention policy is configurable via the 'endpoints_log_retention_in_days' variable.
# 3. CloudWatch Logs provide visibility into traffic and help troubleshoot issues with VPC Endpoints.
# 4. Tags ensure the log group is easily identifiable and categorized in AWS environments.
# 5. KMS encryption is applied when 'kms_key_arn' is provided, ensuring log data security.