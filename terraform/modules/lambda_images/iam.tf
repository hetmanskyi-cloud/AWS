# --- IAM Role and Policies for Lambda Function --- #
# This file defines the IAM role and necessary permissions for the Lambda function to operate.

# --- IAM Role for Lambda --- #
# This resource creates the IAM role that the Lambda function will assume.
# This role is created unconditionally whenever the module is invoked.
resource "aws_iam_role" "lambda_role" {
  name               = "${var.name_prefix}-${var.lambda_function_name}-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-role-${var.environment}"
  })
}

# --- Assume Role Policy Document --- #
# This data source defines the trust relationship policy for the Lambda function.
# It allows the AWS Lambda service to assume the role defined above.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Core Lambda Permissions Policy --- #
# This policy grants the function essential permissions to operate.
resource "aws_iam_policy" "lambda_core_permissions" {
  name        = "${var.name_prefix}-${var.lambda_function_name}-core-policy-${var.environment}"
  description = "Core permissions for the Lambda function, including CloudWatch, SQS, S3, and DynamoDB access."
  policy      = data.aws_iam_policy_document.lambda_core_permissions.json
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-core-policy-${var.environment}"
  })
}

# --- Core Permissions Policy Document --- #
# This data source defines the JSON for the core permissions policy, granting
# access to all necessary services for the SQS -> Lambda -> DynamoDB workflow.
data "aws_iam_policy_document" "lambda_core_permissions" {
  # Allow the function to create and write to its own CloudWatch log group.
  statement {
    sid    = "AllowCreateOwnLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"]
  }

  statement {
    sid    = "AllowWriteToOwnLogStream"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.name_prefix}-${var.lambda_function_name}-${var.environment}:*"]
  }

  # Allow sending failed invocation records to the SQS Dead Letter Queue.
  statement {
    sid       = "AllowSendingToDLQ"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.dead_letter_queue_arn]
  }

  # Allow the Lambda service to poll and manage messages from the main SQS trigger queue.
  statement {
    sid    = "AllowReadingFromSQSTrigger"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [var.sqs_trigger_queue_arn]
  }

  # Allow writing metadata items to the DynamoDB table.
  statement {
    sid    = "AllowWriteToDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  # Allow reading source images from the specified S3 bucket and prefix.
  statement {
    sid    = "AllowReadFromSourceS3"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["arn:aws:s3:::${var.source_s3_bucket_name}/${var.source_s3_prefix}*"]
  }

  # Allow writing processed images to the specified S3 bucket and prefix.
  statement {
    sid    = "AllowWriteToDestinationS3"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::${var.source_s3_bucket_name}/${var.destination_s3_prefix}*"]
  }

  # Grant permissions to use the KMS key for decrypting SQS messages and S3 objects.
  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    # Permission is scoped to the specific key used by our services.
    resources = [var.kms_key_arn]
  }
}

# --- Attach Core Policy to Lambda Role --- #
# Attaches the core permissions policy to the created Lambda IAM role.
resource "aws_iam_role_policy_attachment" "lambda_core_permissions_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_core_permissions.arn
}

# --- Attach Additional Managed Policies --- #
# This resource attaches any additional, pre-existing IAM policies to the role.
resource "aws_iam_role_policy_attachment" "lambda_additional_attachments" {
  for_each   = toset(var.lambda_iam_policy_attachments)
  role       = aws_iam_role.lambda_role.name
  policy_arn = each.value
}

# --- Notes --- #
# 1. Unconditional Creation: The IAM role and its core policy are created unconditionally as an integral part of this module.
# 2. Comprehensive Permissions: The core policy now includes all necessary permissions for the full workflow:
#    a. CloudWatch Logs: For debugging and monitoring.
#    b. SQS Trigger Queue: To receive, delete, and inspect messages.
#    c. SQS DLQ: To send messages upon failure.
#    d. DynamoDB Table: To write metadata items.
#    e. S3 Bucket: To get source images and put processed images.
# 3. Least Privilege: All permissions are scoped to specific resource ARNs passed into the module,
#    adhering to the principle of least privilege.
