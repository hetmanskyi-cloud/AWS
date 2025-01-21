# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.
# The Lambda function automatically updates the `ExpirationTime` attribute for DynamoDB records,
# ensuring stale locks are cleaned up via TTL.

# --- IAM Role for Lambda --- #
# Grants the necessary permissions for the Lambda function to interact with DynamoDB.
resource "aws_iam_role" "lambda_execution_role" {
  count = var.enable_lambda && var.enable_dynamodb ? 1 : 0

  name = "${var.name_prefix}-lambda-execution-role"

  # Trust relationship for Lambda service.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-lambda-execution-role"
    Environment = var.environment
  }
}

# --- Security Group for Lambda --- #
# Provides network access control for the Lambda function.
resource "aws_security_group" "lambda_sg" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  # Ingress rules are NOT needed in most cases for Lambda with Event Source Mappings.

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # This is only for demonstration and should be replaced with VPC endpoints or prefix lists.
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

# --- Separate IAM Policy for DynamoDB Access --- #
# Defines a standalone policy with the required DynamoDB permissions.
# Provides only the necessary permissions for Lambda to process DynamoDB Streams.
# The actions are limited to read/write operations and stream management.
resource "aws_iam_policy" "dynamodb_access_policy" {
  count = var.enable_lambda && var.enable_dynamodb ? 1 : 0

  name        = "${var.name_prefix}-dynamodb-access"
  description = "IAM policy for Lambda to access DynamoDB Streams and update records"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.terraform_locks[0].arn
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.terraform_locks[0].stream_arn
      }
    ]
  })
}

# --- IAM Role Policy Attachment --- #
# Attaches the DynamoDB access policy to the Lambda execution role.
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  count = var.enable_lambda && var.enable_dynamodb ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name
  policy_arn = aws_iam_policy.dynamodb_access_policy[0].arn
}

# --- Lambda Function Definition --- #
# Defines the Lambda function that processes DynamoDB Streams.
# This resource is only created if DynamoDB Streams are enabled and the table exists.
# This Lambda function is used to automate TTL management for the DynamoDB table.
# It updates the expiration timestamps to avoid stale locks.
# Note: If TTL automation is not required, this Lambda can be disabled or removed.
resource "aws_lambda_function" "update_ttl" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 ? 1 : 0

  filename      = "${path.root}/scripts/update_ttl.zip" # Path to the Lambda function code.
  function_name = "${var.name_prefix}-update-ttl"
  role          = aws_iam_role.lambda_execution_role[0].arn
  runtime       = "python3.12"                # Runtime environment for the Lambda function.
  handler       = "update_ttl.lambda_handler" # Entry point of the Lambda function.

  # Configure VPC networking for the Lambda function.
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg[0].id]
  }

  # Define creation and update timeouts to avoid long waits in case of deployment issues.
  timeouts {
    create = "5m" # Allow up to 5 minutes for Lambda creation
    update = "5m" # Allow up to 5 minutes for Lambda updates
    delete = "5m" # Allow up to 5 minutes for Lambda deletion
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-update-ttl"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  count = var.enable_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-update-ttl" # Log group name follows AWS Lambda convention
  retention_in_days = var.lambda_log_retention_days               # Use variable for flexibility

  tags = {
    Name        = "${var.name_prefix}-lambda-log-group"
    Environment = var.environment
  }
}

# --- Dead Letter Queue for Lambda --- #
# Stores failed event processing records from Lambda
resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_lambda ? 1 : 0

  name = "${var.name_prefix}-lambda-dlq"

  tags = {
    Name        = "${var.name_prefix}-lambda-dlq"
    Environment = var.environment
  }
}

# --- Event Source Mapping --- #
# Connects the Lambda function to DynamoDB Streams.
resource "aws_lambda_event_source_mapping" "dynamodb_to_lambda" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 ? 1 : 0

  event_source_arn               = aws_dynamodb_table.terraform_locks[0].stream_arn # DynamoDB Streams ARN.
  function_name                  = aws_lambda_function.update_ttl[0].arn            # Lambda function ARN.
  batch_size                     = 100                                              # Number of records to process per batch.
  starting_position              = "LATEST"                                         # Start processing from the latest stream record.
  maximum_retry_attempts         = 5                                                # Number of retries of processing
  maximum_record_age_in_seconds  = 600                                              # Maximum age of a record in a stream
  bisect_batch_on_function_error = true                                             # Split into parts on error 

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.lambda_dlq[0].arn
    }
  }
}

# --- IAM Policy for Lambda DLQ Access --- #
# This policy grants the Lambda function permission to send messages to the SQS Dead Letter Queue (DLQ).
# It ensures that unprocessed events are captured in the DLQ for further inspection and debugging.
resource "aws_iam_policy" "lambda_dlq_access" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-dlq-policy"              # Policy name with prefix for uniqueness.
  description = "Allow Lambda function to send messages to SQS DLQ" # Description of the policy.

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",              # Allows Lambda to send messages to the DLQ.
        Resource = aws_sqs_queue.lambda_dlq[0].arn # Specifies the target SQS queue ARN.
      }
    ]
  })
}

# --- IAM Role Policy Attachment for Lambda DLQ Access --- #
# This resource attaches the created DLQ access policy to the Lambda execution role.
# It ensures the Lambda function has the necessary permissions to interact with the DLQ.
resource "aws_iam_role_policy_attachment" "lambda_dlq_policy_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name # Attach policy to the Lambda execution role.
  policy_arn = aws_iam_policy.lambda_dlq_access[0].arn    # Reference the created policy.
}

# --- Retrieve current AWS region and account ID --- #

# These data sources are used to dynamically populate ARNs in IAM policies.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- IAM Policy for Lambda CloudWatch Logs --- #
# This policy allows the Lambda function to create and write logs to CloudWatch Logs.
resource "aws_iam_policy" "lambda_cloudwatch_logs_policy" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-cloudwatch-logs-policy"
  description = "IAM policy for Lambda to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",  # Allows creation of new log groups if they don't exist
          "logs:CreateLogStream", # Allows creation of new log streams within log groups
          "logs:PutLogEvents"     # Allows writing log events to the streams
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.update_ttl[0].function_name}:*"
      }
    ]
  })
}

# --- IAM Role Policy Attachment for CloudWatch Logs --- #
# Attaches the CloudWatch Logs policy to the Lambda execution role.
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs_policy_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name
  policy_arn = aws_iam_policy.lambda_cloudwatch_logs_policy[0].arn
}

# --- Notes --- #
# 1. **Purpose**:
#    - This Lambda function automates the management of the `ExpirationTime` attribute in the DynamoDB table used for Terraform locks.
#    - It helps clean up stale locks by updating expiration timestamps automatically.
#
# 2. **Key Features**:
#    - Automatically updates expiration timestamps to avoid stale locks.
#    - Processes DynamoDB Streams for real-time updates.
#    - Supports Dead Letter Queue (DLQ) for capturing failed processing events.
#    - CloudWatch log group with configurable retention period to monitor function execution.
#    - Configurable timeouts for create, update, and delete operations.
#
# 3. **Best Practices**:
#    - Ensure the `update_ttl.zip` file is updated with the latest function logic before applying changes.
#      - Outdated code may cause unexpected behavior in the DynamoDB lock cleanup process.
#    - Use the least privilege principle when defining IAM policies for the Lambda function.
#    - Set an appropriate retention period for logs to balance cost and compliance.
#
# 4. **Integration**:
#    - The `aws_lambda_event_source_mapping.dynamodb_to_lambda` resource links this Lambda function to the DynamoDB Streams defined in `s3/dynamodb.tf`.
#    - CloudWatch logs provide insights into the Lambda function's execution.
#    - SQS Dead Letter Queue (DLQ) captures failed records for further analysis and debugging.
#    - Security Group allows outbound traffic to AWS services while restricting unnecessary access.
#
# 5. **Conditional Creation**:
#    - The `enable_lambda` variable controls whether Lambda resources are created.
#    - The `enable_dynamodb` variable must also be set to true for proper operation.
#    - When both `enable_lambda = false` and `enable_dynamodb = false`, all related resources are skipped.
#    - If `enable_lambda = true` but `enable_dynamodb = false`, Terraform will fail due to missing dependencies.
#
# 6. **Resource Timeout Configuration**:
#    - Lambda function includes a timeout configuration:
#      - Create: 5 minutes
#      - Update: 5 minutes
#      - Delete: 5 minutes
#    - These settings help prevent Terraform from hanging during deployment issues.
#
# 7. **Log Retention**:
#    - The log retention period for the CloudWatch log group is configurable via `lambda_log_retention_days`.
#    - Default log retention is set to 30 days but can be adjusted via Terraform variables.
#
# 8. **Validation**:
#    - Ensure the appropriate permissions are applied to the Lambda execution role.
#    - Check that the SQS DLQ is correctly capturing failed event processing.
#    - Validate that CloudWatch logs capture the function output without exceeding retention limits.
#
# 9. **Testing**:
#    - Test the `enable_lambda` and `enable_dynamodb` variables in different combinations to ensure correct resource creation or omission:
#      - Both enabled: All resources are created, and integration works as expected.
#      - Both disabled: No resources are created, and Terraform applies cleanly.
#      - Only Lambda enabled: Expect a validation failure due to missing DynamoDB resources.
#    - Ensure that the Lambda function processes DynamoDB Stream records as expected.
#    - Test with various TTL expiration times to validate the cleanup logic.