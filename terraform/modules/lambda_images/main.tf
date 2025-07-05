# --- Terraform and Provider Requirements --- #
# This block declares the minimum required versions of Terraform and the providers
# used within this module to ensure compatibility and stability.
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# --- Main Lambda Module Configuration --- #
# This file defines the core resources: the Lambda function itself,
# its source code packaging, and its SQS trigger configuration.

# --- Lambda Deployment Package --- #
# This data source archives the Lambda source code from the specified local path into a ZIP file.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_code_path
  output_path = "${path.module}/lambda_deployment_package.zip"
}

# --- AWS Lambda Function --- #
# This is the main resource that creates the Lambda function.
resource "aws_lambda_function" "image_processor" {
  function_name = "${var.name_prefix}-${var.lambda_function_name}-${var.environment}"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  architectures = var.lambda_architecture

  # The IAM role is created and managed entirely within this module.
  role = aws_iam_role.lambda_role.arn

  # Deployment package details.
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # A list of Lambda Layer Version ARNs to attach to the function.
  layers = var.lambda_layers

  # The amount of ephemeral storage (/tmp) to allocate for the function.
  ephemeral_storage {
    size = var.ephemeral_storage_mb
  }

  # Configuration for the Dead Letter Queue (DLQ).
  dead_letter_config {
    target_arn = var.dead_letter_queue_arn
  }

  # Environment variables for the function's runtime.
  environment {
    variables = merge(
      var.lambda_environment_variables, # Static variables (e.g., TARGET_WIDTH)
      {
        # Dynamic variables passed into the module separately
        DYNAMODB_TABLE_NAME = var.dynamodb_table_name
        DESTINATION_PREFIX  = var.destination_s3_prefix
      }
    )
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-${var.environment}"
  })
}

# --- SQS Trigger Configuration --- #
# This resource creates the mapping between the SQS queue and the Lambda function.
# It allows the Lambda service to poll the queue and invoke the function with messages.
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  # We can use a variable here to enable/disable the trigger if needed,
  # but for now, we assume it's always on if the module is used.
  event_source_arn = var.sqs_trigger_queue_arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = var.sqs_batch_size
}

# --- Cleanup on Destroy --- #
# This resource runs ONLY during 'terraform destroy' to remove the ZIP package
# created by the 'archive_file' data source.
resource "null_resource" "package_cleanup" {
  # This trigger ensures the resource is part of the dependency graph.
  triggers = {
    function_arn = aws_lambda_function.image_processor.arn
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/lambda_deployment_package.zip"
  }
}

# --- Notes --- #
# 1. Architecture: This module implements an SQS-triggered function.
#    The connection is managed by the `aws_lambda_event_source_mapping` resource.
# 2. SQS Polling: The Lambda service will poll the specified SQS queue. The IAM policy in `iam.tf` grants
#    the necessary permissions (`ReceiveMessage`, `DeleteMessage`, etc.) for this to work.
# 3. Batch Size: The `batch_size` variable controls how many messages the function receives at once,
#    allowing for performance tuning.
# 4. Mandatory Features: The function is always configured with a Dead Letter Queue (`dead_letter_config`) for robust error handling.
