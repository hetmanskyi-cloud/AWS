# --- DynamoDB Module Outputs ---
# This file defines the outputs that the module exposes. These outputs allow other
# modules or the root configuration to reference the created DynamoDB table.

# --- Table ARN --- #
# The ARN is the globally unique identifier for the table.
output "dynamodb_table_arn" {
  description = "The Amazon Resource Name (ARN) of the DynamoDB table. Essential for IAM policy integration."
  value       = aws_dynamodb_table.dynamodb_table.arn
}

# --- Table Name --- #
# The name of the table is often required by application code.
output "dynamodb_table_name" {
  description = "The name of the DynamoDB table. Useful for application code that needs to reference the table."
  value       = aws_dynamodb_table.dynamodb_table.id # For aws_dynamodb_table, the 'id' attribute is the table name.
}

# --- Notes --- #
# 1. ARN vs. Name: The `table_arn` should be used in IAM policies to grant permissions,
#    while the `table_name` is typically passed as an environment variable to applications
#    (e.g., a Lambda function) so they know which table to interact with.
# 2. Extensibility: If features like DynamoDB Streams were added to this module in the future,
#    their attributes (e.g., `stream_arn`) would also be exposed here.
