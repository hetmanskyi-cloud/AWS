# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.

# --- IAM Roles and Policies --- #

# --- IAM Role for Lambda --- #
# Role for Lambda execution, grants DynamoDB interaction permissions.
resource "aws_iam_role" "lambda_execution_role" {
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

  name = "${var.name_prefix}-lambda-execution-role" # IAM Role name

  # Trust relationship for Lambda service.
  assume_role_policy = jsonencode({ # Trust policy for Lambda
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
  tags = { # Resource tags
    Name        = "${var.name_prefix}-lambda-execution-role"
    Environment = var.environment
  }
}

# --- IAM Policy for DynamoDB Access --- #
# Policy for Lambda to access DynamoDB Streams.
resource "aws_iam_policy" "dynamodb_access_policy" {
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

  name        = "${var.name_prefix}-dynamodb-access"            # Policy name
  description = "IAM policy for Lambda DynamoDB Streams access" # Policy description

  policy = jsonencode({ # Policy statement
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.terraform_locks[0].arn # Resource: DynamoDB Table ARN
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.terraform_locks[0].stream_arn # Resource: DynamoDB Stream ARN
      }
    ]
  })
}

# --- IAM Role Policy Attachment (DynamoDB) --- #
# Attaches DynamoDB access policy to Lambda role.
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  count = (var.enable_lambda ? 1 : 0) * (var.enable_dynamodb ? 1 : 0)

  role       = aws_iam_role.lambda_execution_role[0].name   # Lambda Role name
  policy_arn = aws_iam_policy.dynamodb_access_policy[0].arn # DynamoDB Policy ARN
}

# --- IAM Policy for Lambda DLQ Access --- #
# Policy to allow Lambda to send messages to SQS DLQ.
resource "aws_iam_policy" "lambda_dlq_access" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-dlq-policy" # Policy name
  description = "Policy for Lambda SQS DLQ access"     # Policy description

  policy = jsonencode({ # Policy statement
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",              # Action: SendMessage
        Resource = aws_sqs_queue.lambda_dlq[0].arn # Resource: SQS DLQ ARN
      }
    ]
  })
}

# --- IAM Policy for SQS KMS Access --- #
# Policy for Lambda KMS access to SQS.
resource "aws_iam_policy" "sqs_kms_access" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-sqs-kms-policy" # Policy name
  description = "Policy for Lambda SQS KMS access"  # Policy description

  policy = jsonencode({ # Policy statement
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",        # Action: kms:Decrypt
          "kms:GenerateDataKey" # Action: kms:GenerateDataKey
        ],
        Resource = var.kms_key_arn # Resource: KMS Key ARN
      }
    ]
  })
}

# --- IAM Role Policy Attachment (SQS KMS) --- #
# Attaches SQS KMS policy to Lambda role.
resource "aws_iam_role_policy_attachment" "lambda_sqs_kms_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name # Lambda Role name
  policy_arn = aws_iam_policy.sqs_kms_access[0].arn       # SQS KMS Policy ARN
}

# --- IAM Role Policy Attachment (DLQ) --- #
# Attaches DLQ access policy to Lambda role.
resource "aws_iam_role_policy_attachment" "lambda_dlq_policy_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name # Lambda Role name
  policy_arn = aws_iam_policy.lambda_dlq_access[0].arn    # DLQ Policy ARN
}

# --- IAM Policy for Lambda CloudWatch Logs --- #
# Policy for Lambda to write logs to CloudWatch Logs.
resource "aws_iam_policy" "lambda_cloudwatch_logs_policy" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-cloudwatch-logs-policy" # Policy name
  description = "Policy for Lambda CloudWatch Logs access"         # Policy description

  policy = jsonencode({ # Policy statement
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",     # Action: logs:CreateLogGroup
          "logs:CreateLogStream",    # Action: logs:CreateLogStream
          "logs:PutLogEvents",       # Action: logs:PutLogEvents
          "logs:PutRetentionPolicy", # Action: logs:PutRetentionPolicy
          "logs:DescribeLogGroups",  # Action: logs:DescribeLogGroups
          "logs:DescribeLogStreams"  # Action: logs:DescribeLogStreams
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${try(aws_lambda_function.update_ttl[0].function_name, "")}:*" # Resource: CloudWatch Logs ARN
      }
    ]
  })
}

# --- IAM Role Policy Attachment (CloudWatch Logs) --- #
# Attaches CloudWatch Logs policy to Lambda role.
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs_policy_attachment" {
  count = var.enable_lambda ? 1 : 0

  role       = aws_iam_role.lambda_execution_role[0].name          # Lambda Role name
  policy_arn = aws_iam_policy.lambda_cloudwatch_logs_policy[0].arn # CloudWatch Logs Policy ARN
}

# --- Network Settings --- #

# --- Security Group for Lambda --- #
# Security Group for Lambda function.
resource "aws_security_group" "lambda_sg" {
  count = var.enable_lambda ? 1 : 0

  name        = "${var.name_prefix}-lambda-sg"       # SG Name
  description = "Security Group for Lambda function" # SG Description
  vpc_id      = var.vpc_id                           # VPC ID

  # Egress rule for VPC Endpoints
  egress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    prefix_list_ids = try([ # VPC Endpoint Prefix Lists
      var.dynamodb_endpoint_id,
      var.cloudwatch_logs_endpoint_id,
      var.sqs_endpoint_id,
      var.kms_endpoint_id,
      var.lambda_endpoint_id
    ], [])

    description = "Allow HTTPS to AWS services via VPC Endpoints" # Allow HTTPS to VPC Endpoints
  }

  # Tags for resource identification.
  tags = { # Resource tags
    Name        = "${var.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

# --- Queues & Logging --- #

# --- Dead Letter Queue (DLQ) for Lambda --- #
# SQS Queue for Lambda DLQ.
resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_lambda ? 1 : 0

  name = "${var.name_prefix}-lambda-dlq" # SQS Queue Name

  # KMS encryption from KMS module
  kms_master_key_id = var.kms_key_arn # KMS Key ARN

  tags = { # Resource tags
    Name        = "${var.name_prefix}-lambda-dlq"
    Environment = var.environment
  }
}

# --- CloudWatch Log Group for Lambda --- #
# CloudWatch Log Group for Lambda function.
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  count = var.enable_lambda ? 1 : 0

  name              = "/aws/lambda/${var.name_prefix}-update-ttl" # Log Group Name
  retention_in_days = var.lambda_log_retention_days               # Log retention days
  kms_key_id        = var.kms_key_arn                             # KMS Key ARN

  tags = { # Resource tags
    Name        = "${var.name_prefix}-lambda-log-group"
    Environment = var.environment
  }
}

# --- Lambda Function --- #

# --- Lambda Function Definition --- #
# Lambda function for DynamoDB Streams processing (TTL automation).
resource "aws_lambda_function" "update_ttl" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 && fileexists("${path.root}/scripts/update_ttl.zip") ? 1 : 0

  filename      = "${path.root}/scripts/update_ttl.zip"     # ZIP archive path
  function_name = "${var.name_prefix}-update-ttl"           # Lambda Function Name
  role          = aws_iam_role.lambda_execution_role[0].arn # IAM Role ARN
  runtime       = "python3.12"                              # Runtime: python3.12
  handler       = "update_ttl.lambda_handler"               # Handler: update_ttl.lambda_handler

  reserved_concurrent_executions = 2  # Reserved concurrency: 2
  timeout                        = 30 # Timeout: 30 seconds

  dead_letter_config {                           # DLQ config
    target_arn = aws_sqs_queue.lambda_dlq[0].arn # DLQ ARN
  }

  vpc_config {                                                # VPC config
    subnet_ids         = var.private_subnet_ids               # Subnet IDs
    security_group_ids = [aws_security_group.lambda_sg[0].id] # Security Group IDs
  }

  timeouts {      # Timeouts
    create = "5m" # Create timeout: 5 minutes
    update = "5m" # Update timeout: 5 minutes
    delete = "5m" # Delete timeout: 5 minutes
  }

  depends_on = [ # Dependencies
    var.dynamodb_endpoint_id,
    var.cloudwatch_logs_endpoint_id,
    var.sqs_endpoint_id,
    var.kms_endpoint_id
  ]

  tags = { # Resource tags
    Name        = "${var.name_prefix}-update-ttl"
    Environment = var.environment
  }
}

# --- CloudWatch Event Invoke Config --- #
# Config for Lambda event invoke (retries, error handling).
resource "aws_lambda_function_event_invoke_config" "update_ttl_config" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 ? 1 : 0

  function_name                = aws_lambda_function.update_ttl[0].function_name # Lambda Function Name
  maximum_retry_attempts       = 2                                               # Max retry attempts: 2
  maximum_event_age_in_seconds = 300                                             # Max event age: 300 seconds (5 min)

  destination_config {                              # Destination config
    on_failure {                                    # On failure
      destination = aws_sqs_queue.lambda_dlq[0].arn # Failure destination: DLQ ARN
    }
  }
}

# --- Event Source Mapping --- #
# Connects Lambda to DynamoDB Streams.
resource "aws_lambda_event_source_mapping" "dynamodb_to_lambda" {
  count = var.enable_lambda && var.enable_dynamodb && length(aws_dynamodb_table.terraform_locks) > 0 ? 1 : 0

  event_source_arn               = aws_dynamodb_table.terraform_locks[0].stream_arn # DynamoDB Stream ARN
  function_name                  = aws_lambda_function.update_ttl[0].arn            # Lambda Function ARN
  batch_size                     = 100                                              # Batch size: 100
  starting_position              = "LATEST"                                         # Starting position: LATEST
  maximum_retry_attempts         = 5                                                # Max retry attempts: 5
  maximum_record_age_in_seconds  = 600                                              # Max record age: 600 seconds (10 min)
  bisect_batch_on_function_error = true                                             # Bisect batch on error: true

  destination_config {                                  # Destination config
    on_failure {                                        # On failure
      destination_arn = aws_sqs_queue.lambda_dlq[0].arn # Failure destination: DLQ ARN
    }
  }
}

# --- CloudWatch Alarms for Lambda Errors --- #
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_lambda ? 1 : 0
  alarm_name          = "${var.name_prefix}-lambda-errors" # Alarm Name
  comparison_operator = "GreaterThanThreshold"             # Comparison: GreaterThanThreshold
  evaluation_periods  = "1"                                # Evaluation periods: 1
  metric_name         = "Errors"                           # Metric: Errors
  namespace           = "AWS/Lambda"                       # Namespace: AWS/Lambda
  period              = "300"                              # Period: 300 seconds (5 min)
  statistic           = "Sum"                              # Statistic: Sum
  threshold           = "1"                                # Threshold: 1 (any error)
  alarm_description   = "Alarm for Lambda function errors" # Alarm description
  alarm_actions       = [var.sns_topic_arn]                # Alarm actions: SNS Topic ARN
  ok_actions          = [var.sns_topic_arn]                # OK actions: SNS Topic ARN

  dimensions = {                                                   # Dimensions
    FunctionName = aws_lambda_function.update_ttl[0].function_name # Function Name dimension
  }

  tags = { # Resource tags
    Name        = "${var.name_prefix}-lambda-errors-alarm"
    Environment = var.environment
  }
}

# --- Data Sources for AWS Region and Account ID --- #
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- Notes --- #
# General notes for Lambda function.

# 1. Lambda Purpose: DynamoDB Streams processing for Terraform state locking (TTL management).
# 2. Security: VPC Endpoints, least privilege IAM, prefix lists for outbound access, HTTPS enforced.
# 3. Conditional Creation: Based on var.enable_lambda, var.enable_dynamodb.
# 4. Dependencies: VPC Endpoints (DynamoDB, CloudWatch Logs, SQS, KMS), DynamoDB table.
# 5. Monitoring & Logging: CloudWatch Logs, DLQ, KMS encryption.
# 6. Best Practices: Consistent naming (var.name_prefix), resource tagging, DLQ error handling, secure VPC config.