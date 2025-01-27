# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.

# --- IAM Roles and Policies (Preparing Access Rights) --- #

# --- IAM Role for Lambda --- #
# Grants the necessary permissions for the Lambda function to interact with DynamoDB.
resource "aws_iam_role" "lambda_execution_role" {
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

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

# --- IAM Policy for DynamoDB Access --- #
# Defines a standalone policy with the required DynamoDB permissions.
# Provides only the necessary permissions for Lambda to process DynamoDB Streams.
# The actions are limited to read/write operations and stream management.
resource "aws_iam_policy" "dynamodb_access_policy" {
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

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
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

  role       = aws_iam_role.lambda_execution_role[0].name
  policy_arn = aws_iam_policy.dynamodb_access_policy[0].arn
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

# --- IAM Policy for SQS KMS Access --- #
# This policy grants the Lambda function permissions to encrypt and decrypt messages in the SQS queue.
# It allows the Lambda function to securely process messages using the provided KMS key.
resource "aws_iam_policy" "sqs_kms_access" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-sqs-kms-policy" # Policy name with prefix for uniqueness.
  description = "Allow Lambda to encrypt/decrypt messages in SQS using KMS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",        # Allow decryption of messages in SQS
          "kms:GenerateDataKey" # Allow generation of encryption keys for messages
        ],
        Resource = var.kms_key_arn # ARN of the KMS key used for encryption
      }
    ]
  })
}

# --- IAM Role Policy Attachment for Lambda SQS KMS Access --- #
# Attaches the SQS KMS access policy to the Lambda execution role.
# This ensures the Lambda function has the necessary permissions to interact with encrypted SQS messages.
resource "aws_iam_role_policy_attachment" "lambda_sqs_kms_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name # Attach policy to the Lambda execution role
  policy_arn = aws_iam_policy.sqs_kms_access[0].arn       # Reference the created policy
}

# --- IAM Role Policy Attachment for Lambda DLQ Access --- #
# This resource attaches the created DLQ access policy to the Lambda execution role.
# It ensures the Lambda function has the necessary permissions to interact with the DLQ.
resource "aws_iam_role_policy_attachment" "lambda_dlq_policy_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name # Attach policy to the Lambda execution role.
  policy_arn = aws_iam_policy.lambda_dlq_access[0].arn    # Reference the created policy.
}

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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${try(aws_lambda_function.update_ttl[0].function_name, "")}:*"
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

# --- Network settings (providing access) --- #

# --- Security Group for Lambda --- #
# Provides network access control for the Lambda function.
resource "aws_security_group" "lambda_sg" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  # Ingress rules are NOT needed in most cases for Lambda with Event Source Mappings.

  # Allowing access to VPC Endpoints via prefix lists
  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    prefix_list_ids = try([
      data.aws_vpc_endpoint.dynamodb.prefix_list_id,
      data.aws_vpc_endpoint.cloudwatch_logs.prefix_list_id,
      data.aws_vpc_endpoint.sqs.prefix_list_id,
      data.aws_vpc_endpoint.kms.prefix_list_id,
      data.aws_vpc_endpoint.lambda.prefix_list_id
    ], [])

    description = "Allow HTTPS to AWS services via VPC Endpoints"
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

# --- Queues and Logging (DLQ and CloudWatch Logs) --- #

# --- Dead Letter Queue for Lambda --- #
# Stores failed event processing records from Lambda
resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_lambda ? 1 : 0

  name = "${var.name_prefix}-lambda-dlq"

  # Use the shared KMS key from the KMS module
  kms_master_key_id = var.kms_key_arn # This value should be passed from the KMS module output

  tags = {
    Name        = "${var.name_prefix}-lambda-dlq"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  count = var.enable_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-update-ttl" # Log group name follows AWS Lambda convention
  retention_in_days = var.lambda_log_retention_days               # Use variable for flexibility
  kms_key_id        = var.kms_key_arn                             # Use KMS key for encryption

  tags = {
    Name        = "${var.name_prefix}-lambda-log-group"
    Environment = var.environment
  }
}

# --- Lambda function (defining core functionality) --- #

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

  # Limit concurrent executions to prevent overuse
  reserved_concurrent_executions = 2 # Limiting to 2 parallel executions for state consistency

  # Set function execution timeout to 30 seconds
  timeout = 30 # Recommended timeout for DynamoDB Stream processing

  # DLQ for error handling
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq[0].arn
  }

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

# --- CloudWatch Event Invoke Config for Lambda --- #
# Configures event invoke settings to control retries and error handling.
resource "aws_lambda_function_event_invoke_config" "update_ttl_config" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 ? 1 : 0

  function_name                = aws_lambda_function.update_ttl[0].function_name
  maximum_retry_attempts       = 2   # Limit retry attempts to 2
  maximum_event_age_in_seconds = 300 # Maximum event age of 5 minutes

  destination_config {
    on_failure {
      destination = aws_sqs_queue.lambda_dlq[0].arn # Send failed events to DLQ
    }
  }
}

# --- Connecting Lambda to Event Sources --- #

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

# --- CloudWatch Alarms for Lambda Monitoring --- #
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_lambda ? 1 : 0
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300" # 5 minutes
  statistic           = "Sum"
  threshold           = "1" # Any error will trigger the alarm
  alarm_description   = "This metric monitors lambda function errors"
  alarm_actions       = [var.sns_topic_arn] # Using existing SNS topic
  ok_actions          = [var.sns_topic_arn] # Notify when alarm returns to OK state

  dimensions = {
    FunctionName = aws_lambda_function.update_ttl[0].function_name
  }

  tags = {
    Name        = "${var.name_prefix}-lambda-errors-alarm"
    Environment = var.environment
  }
}

# --- Data Sources for AWS Region and Account ID --- #
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- Data Sources for VPC Endpoints --- #

data "aws_vpc_endpoint" "lambda" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.lambda"
}

data "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
}

data "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.logs"
}

data "aws_vpc_endpoint" "sqs" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.sqs"
}

data "aws_vpc_endpoint" "kms" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.kms"
}

# --- Notes --- #

# 1. **Lambda Function Purpose**:
#    - Processes DynamoDB Streams for Terraform state locking
#    - Monitors and processes state lock records
#    - Helps manage Terraform state locks through DynamoDB streams
#
# 2. **Security Configuration**:
#    - Uses VPC Endpoints for secure service communication
#    - Implements least privilege principle in IAM policies
#    - Restricts outbound traffic to specific AWS services via prefix lists
#    - All traffic is encrypted via HTTPS (port 443)
#
# 3. **Conditional Creation**:
#    - Resources are created based on var.enable_lambda and var.enable_dynamodb
#    - VPC Endpoint data sources use count for conditional lookup
#    - Security group rules adapt to enabled endpoints
#
# 4. **Dependencies**:
#    - Requires configured VPC Endpoints for:
#      * DynamoDB
#      * CloudWatch Logs
#      * SQS
#      * KMS
#    - Depends on DynamoDB table for stream processing
#
# 5. **Monitoring and Logging**:
#    - CloudWatch Logs integration for Lambda logs
#    - DLQ configuration for failed executions
#    - KMS encryption for sensitive data
#
# 6. **Best Practices**:
#    - Resources named using var.name_prefix for consistency
#    - All resources properly tagged
#    - Proper error handling via DLQ
#    - Secure network configuration via VPC Endpoints