# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

# --- Main Lambda Module Configuration --- #
# This file defines the core resources: the Lambda function itself,
# its source code packaging, and the S3 trigger configuration.

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
  # This is a mandatory feature for the module, so the block is unconditional.
  dead_letter_config {
    target_arn = var.dead_letter_queue_arn
  }

  # Environment variables for the function's runtime.
  environment {
    variables = var.environment_variables
  }

  tags = merge(var.tags, {
    Name = var.lambda_function_name
  })
}

# --- S3 Trigger Configuration --- #
# The following two resources set up the S3 trigger for the Lambda function.
# They are created only if `s3_trigger_enabled` is true.

# 1. Lambda Permission
# Grants the S3 service permission to invoke this Lambda function.
resource "aws_lambda_permission" "s3_invoke" {
  count = var.s3_trigger_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.triggering_bucket_id}"
}

# 2. S3 Bucket Notification
# Configures the S3 bucket to send event notifications to the Lambda function.
resource "aws_s3_bucket_notification" "s3_notification" {
  count = var.s3_trigger_enabled ? 1 : 0

  bucket = var.triggering_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = var.s3_events
    filter_prefix       = var.filter_prefix
    filter_suffix       = var.filter_suffix
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# --- Notes --- #
# 1. Atomic Module: This module creates a Lambda function with its core dependencies (IAM Role, DLQ config) as a single unit.
# 2. Source Code Packaging: The `archive_file` data source handles zipping the source code.
# 3. S3 Trigger: The trigger is configured conditionally via `var.s3_trigger_enabled`, allowing the function to be created without an S3 event source if needed.
# 4. Mandatory Features: The function is always configured with a Dead Letter Queue (`dead_letter_config`) for robust error handling.
# 5. Optional Features: The function's capabilities can be extended with Lambda Layers (`layers`) and increased temporary storage (`ephemeral_storage`).
