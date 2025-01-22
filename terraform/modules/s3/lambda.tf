# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.
# The Lambda function automatically updates the `ExpirationTime` attribute for DynamoDB records,
# ensuring stale locks are cleaned up via TTL.

# --- IAM Roles and Policies (Preparing Access Rights) --- #

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

# --- IAM Policy for DynamoDB Access --- #
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

# --- Network settings (providing access) --- #

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
    description = "Allow all outbound traffic for Lambda function"
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

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.lambda_dlq[0].arn
    maxReceiveCount     = 5 # Number of attempts before sending to DLQ
  })

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

# --- Supporting resources --- #

# Retrieve current AWS region and account ID
# These data sources are used to dynamically populate ARNs in IAM policies.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- Notes --- #

# - Automates the management of the `ExpirationTime` attribute in the DynamoDB table used for Terraform locks.
# - Processes DynamoDB Streams for real-time updates and stale lock cleanup.
# - Supports Dead Letter Queue (DLQ) to capture and analyze failed processing events.
# - Configurable CloudWatch log group retention period to monitor function execution and troubleshooting.
# - Adjustable function execution timeouts for create, update, and delete operations.
# - Implements event invoke configuration for retry attempts and efficient error handling.
# - Applies KMS encryption to SQS to secure message data at rest.
# - Uses Security Group to control outbound traffic, allowing communication only with required AWS services.
# - The `enable_lambda` variable controls resource creation for flexibility across environments.
# - IAM policies follow the least privilege principle to ensure minimal permissions required for operation.
# - Periodic testing with various TTL expiration times ensures expected cleanup behavior.
# - CloudWatch metrics provide insights into invocation rates, errors, and performance for proactive monitoring.