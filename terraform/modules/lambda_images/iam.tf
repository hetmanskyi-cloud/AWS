# --- IAM Role and Policies for Lambda Function --- #
# This file defines the IAM role and necessary permissions for the Lambda function to operate.

# --- IAM Role for Lambda --- #
# This resource creates the IAM role that the Lambda function will assume.
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-${var.lambda_function_name}-role-${var.environment}"

  # The trust policy that grants the Lambda service permission to assume this role.
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
  description = "Core permissions for the Lambda function, including CloudWatch, SQS, and S3 access."

  policy = data.aws_iam_policy_document.lambda_core_permissions.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.lambda_function_name}-core-policy-${var.environment}"
  })
}

# --- Core Permissions Policy Document --- #
# This data source defines the JSON for the core permissions policy.
data "aws_iam_policy_document" "lambda_core_permissions" {
  # Allow writing logs to CloudWatch
  statement {
    sid    = "AllowCloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    # Granting access to all log groups for simplicity.
    resources = ["arn:aws:logs:*:*:*"]
  }

  # Allow sending failed invocation records to the SQS Dead Letter Queue
  statement {
    sid    = "AllowSendingToDLQ"
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    # Grant permission only to the specific SQS queue provided.
    resources = [var.dead_letter_queue_arn]
  }

  # Allow reading source images from the specified S3 bucket and prefix
  statement {
    sid    = "AllowReadFromSourceS3"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    # Restrict read access to the 'uploads' folder (or whatever is passed in var.filter_prefix)
    resources = ["arn:aws:s3:::${var.triggering_bucket_id}/${var.filter_prefix}*"]
  }

  # Allow writing processed images to the specified S3 bucket and prefix
  statement {
    sid    = "AllowWriteToDestinationS3"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    # Restrict write access to the 'processed' folder (or whatever is passed in var.lambda_destination_prefix)
    resources = ["arn:aws:s3:::${var.triggering_bucket_id}/${var.lambda_destination_prefix}*"]
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
# It iterates through the list of ARNs provided in the `lambda_iam_policy_attachments` variable.
resource "aws_iam_role_policy_attachment" "lambda_additional_attachments" {
  for_each = toset(var.lambda_iam_policy_attachments)

  role       = aws_iam_role.lambda_role.name
  policy_arn = each.value
}

# --- Notes --- #
# 1. Unconditional Creation: The IAM role and its core policy are created unconditionally whenever this module is invoked.
# 2. Core Permissions: The policy includes mandatory permissions for:
#    a. CloudWatch Logs (for debugging).
#    b. SQS DLQ (for error handling).
#    c. S3 GetObject (to read source images).
#    d. S3 PutObject (to save processed images).
# 3. Security: Permissions for S3 are restricted to specific prefixes within the bucket to adhere to the principle of least privilege.
# 4. Extensibility: The module allows attaching any number of additional managed IAM policies for other use cases.
