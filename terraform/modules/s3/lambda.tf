# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.
# The Lambda function automatically updates the `ExpirationTime` attribute for DynamoDB records,
# ensuring stale locks are cleaned up via TTL.

# --- IAM Role for Lambda --- #
# Grants the necessary permissions for the Lambda function to interact with DynamoDB.
resource "aws_iam_role" "lambda_execution_role" {
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

  # Inline policy for DynamoDB access.
  inline_policy {
    name = "dynamodb-access"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem"
          ],
          Resource = aws_dynamodb_table.terraform_locks.arn
        },
        {
          Effect = "Allow",
          Action = [
            "dynamodb:DescribeStream",
            "dynamodb:GetRecords",
            "dynamodb:GetShardIterator",
            "dynamodb:ListStreams"
          ],
          Resource = aws_dynamodb_table.terraform_locks.stream_arn
        }
      ]
    })
  }

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-lambda-execution-role"
    Environment = var.environment
  }
}

# --- Lambda Function Definition --- #
# Defines the Lambda function that processes DynamoDB Streams.
resource "aws_lambda_function" "update_ttl" {
  filename      = "${path.root}/scripts/update_ttl.zip" # Path to the Lambda function code.
  function_name = "${var.name_prefix}-update-ttl"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.12"                # Runtime environment for the Lambda function.
  handler       = "update_ttl.lambda_handler" # Entry point of the Lambda function.

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-update-ttl"
    Environment = var.environment
  }
}

# --- Event Source Mapping --- #
# Connects the Lambda function to DynamoDB Streams.
resource "aws_lambda_event_source_mapping" "dynamodb_to_lambda" {
  event_source_arn  = aws_dynamodb_table.terraform_locks.stream_arn # DynamoDB Streams ARN.
  function_name     = aws_lambda_function.update_ttl.arn            # Lambda function ARN.
  batch_size        = 100                                           # Number of records to process per batch.
  starting_position = "LATEST"                                      # Start processing from the latest stream record.
}

# --- Notes --- #
# 1. The IAM role grants the Lambda function permissions to read from DynamoDB Streams and update records.
# 2. The Lambda function is triggered by DynamoDB Streams for every new or modified record.
# 3. The `ExpirationTime` attribute is updated with a new timestamp to ensure proper TTL functionality.
# 4. The Python code for the Lambda function is located in the `scripts/update_ttl.py` file.