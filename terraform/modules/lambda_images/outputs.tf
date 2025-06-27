# --- Lambda Module Outputs --- #
# This file defines the outputs that the module exposes. These outputs can be used
# by other modules or in the root configuration to reference the resources created here.

# --- Lambda Function Outputs --- #

output "lambda_function_arn" {
  description = "The Amazon Resource Name (ARN) of the Lambda function."
  value       = aws_lambda_function.image_processor.arn
}

output "lambda_function_invoke_arn" {
  description = "The ARN to be used for invoking the Lambda function from triggers like API Gateway."
  value       = aws_lambda_function.image_processor.invoke_arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.image_processor.function_name
}

output "lambda_cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group created for the Lambda function."
  # Log group name for Lambda follows a standard convention.
  value = "/aws/lambda/${aws_lambda_function.image_processor.function_name}"
}

# --- IAM Role Outputs --- #

output "lambda_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) of the IAM role created for the Lambda function."
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_iam_role_name" {
  description = "The name of the IAM role created for the Lambda function."
  value       = aws_iam_role.lambda_role.name
}

# --- Notes --- #
# 1. Function ARNs: The `lambda_function_arn` is the primary identifier for the function.
#    The `invoke_arn` is used specifically for certain trigger integrations like API Gateway.
# 2. IAM Role ARN: This output is crucial. It allows other resources (e.g., an S3 bucket policy in another module)
#    to grant permissions directly to this Lambda function's execution role.
# 3. Log Group Name: The name of the CloudWatch Log Group is provided for convenience, for example,
#    to set up custom log subscriptions or metric filters outside of this module.
