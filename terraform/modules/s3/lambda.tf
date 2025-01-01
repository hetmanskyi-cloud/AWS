# --- AWS Lambda for TTL Automation --- #
# This file defines an AWS Lambda function that processes DynamoDB Streams.
# The Lambda function automatically updates the `ExpirationTime` attribute for DynamoDB records,
# ensuring stale locks are cleaned up via TTL.

# --- IAM Role for Lambda --- #
# Grants the necessary permissions for the Lambda function to interact with DynamoDB.
resource "aws_iam_role" "lambda_execution_role" {
  count = var.enable_lambda ? 1 : 0 # Dynamically enable or disable resource creation based on enable_lambda.

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

# --- Separate IAM Policy for DynamoDB Access --- #
# Defines a standalone policy with the required DynamoDB permissions.
resource "aws_iam_policy" "dynamodb_access_policy" {
  count = var.enable_lambda ? 1 : 0 # Dynamically enable or disable resource creation based on enable_lambda.

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
  count = var.enable_lambda ? 1 : 0 # Dynamically enable or disable resource creation based on enable_lambda.

  role       = aws_iam_role.lambda_execution_role[0].name
  policy_arn = aws_iam_policy.dynamodb_access_policy[0].arn
}

# --- Lambda Function Definition --- #
# Defines the Lambda function that processes DynamoDB Streams.
# This Lambda function is used to automate TTL management for the DynamoDB table.
# It updates the expiration timestamps to avoid stale locks.
# Note: If TTL automation is not required, this Lambda can be disabled or removed.
resource "aws_lambda_function" "update_ttl" {
  count = var.enable_lambda ? 1 : 0 # Dynamically enable or disable resource creation based on enable_lambda.

  filename      = "${path.root}/scripts/update_ttl.zip" # Path to the Lambda function code.
  function_name = "${var.name_prefix}-update-ttl"
  role          = aws_iam_role.lambda_execution_role[0].arn
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
  count = var.enable_lambda ? 1 : 0 # Dynamically enable or disable resource creation based on enable_lambda.

  event_source_arn  = aws_dynamodb_table.terraform_locks[0].stream_arn # DynamoDB Streams ARN.
  function_name     = aws_lambda_function.update_ttl[0].arn            # Lambda function ARN.
  batch_size        = 100                                              # Number of records to process per batch.
  starting_position = "LATEST"                                         # Start processing from the latest stream record.
}

# --- Notes --- #
# 1. **Purpose**:
#    - This Lambda function automates the management of the `ExpirationTime` attribute in the DynamoDB table used for Terraform locks.
# 2. **Key Features**:
#    - Automatically updates expiration timestamps to avoid stale locks.
#    - Processes DynamoDB Streams for real-time updates.
# 3. **Best Practices**:
#    - Ensure the `update_ttl.zip` file is deployed and updated whenever the function logic changes.
#    - Use the least privilege principle when defining IAM policies for the Lambda function.
# 4. **Integration**:
#    - The `aws_lambda_event_source_mapping.dynamodb_to_lambda` resource links this Lambda function to the DynamoDB Streams defined in `s3/dynamodb.tf`.
#    - Outputs from the DynamoDB table can be used for monitoring and debugging lock issues.
# 5. **Conditional Creation**:
#    - The `enable_lambda` variable controls whether Lambda resources are created.
#    - When `enable_lambda = false`, all resources in this file are skipped.
#    - Ensure that `enable_lambda = true` is set only when `enable_dynamodb = true`, as the Lambda function depends on the DynamoDB table and streams.
# 6. **Validation**:
#    - If both `enable_lambda` and `enable_dynamodb` are set to false, Terraform will skip all Lambda and DynamoDB-related resources, simplifying the infrastructure for environments where they are not required.
#    - If `enable_lambda = true` but `enable_dynamodb = false`, Terraform will fail due to missing DynamoDB dependencies.
# 7. **Testing**:
#    - Test the `enable_lambda` and `enable_dynamodb` variables in different combinations to ensure correct resource creation or omission:
#      - Both enabled: All resources are created, and integration works as expected.
#      - Both disabled: No resources are created, and Terraform applies cleanly.
#      - Only Lambda enabled: Expect a validation failure due to missing DynamoDB resources.