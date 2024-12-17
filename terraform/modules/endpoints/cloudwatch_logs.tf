# --- CloudWatch Logs Configuration for VPC Endpoints --- #

# --- CloudWatch Log Group --- #
# Creates a CloudWatch Log Group for monitoring VPC Endpoint traffic.
# Enabled only when 'enable_cloudwatch_logs_for_endpoints' is true and the environment is 'stage' or 'prod'.
resource "aws_cloudwatch_log_group" "endpoint_logs" {
  count             = (var.enable_cloudwatch_logs_for_endpoints && var.environment != "dev") ? 1 : 0
  name              = "/aws/vpc-endpoints/${var.name_prefix}"
  retention_in_days = 14 # Default retention period; can be adjusted based on requirements.

  tags = {
    Name        = "${var.name_prefix}-endpoint-logs"
    Environment = var.environment
  }
}

# --- Notes --- #
# 1. This log group is created only when 'enable_cloudwatch_logs_for_endpoints' is set to true.
# 2. The log group is enabled only in stage and prod environments to minimize costs.
# 3. Retention policy is set to 14 days by default and can be modified as needed.
# 4. CloudWatch Logs provide visibility into traffic and help troubleshoot issues with VPC Endpoints.
# 5. Tags ensure the log group is easily identifiable and categorized in AWS environments.