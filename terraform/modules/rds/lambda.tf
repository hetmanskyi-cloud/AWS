# --- IAM Role for Lambda --- #
# Define IAM Role for Lambda functions to interact with RDS
resource "aws_iam_role" "lambda_rds_role" {
  name = "${var.name_prefix}-lambda-rds-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-lambda-role"
    Environment = var.environment
  }
}

# --- Attach Policy for Lambda Role --- #
# Define permissions for creating and deleting read replicas in RDS
resource "aws_iam_policy" "lambda_rds_policy" {
  name = "${var.name_prefix}-lambda-rds-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:CreateDBInstanceReadReplica",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rds_policy_attachment" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = aws_iam_policy.lambda_rds_policy.arn
}

# --- Lambda Function for Creating Read Replicas --- #
# Define Lambda function to create read replicas for RDS
resource "aws_lambda_function" "create_read_replica" {
  function_name = "${var.name_prefix}-create-replica"
  runtime       = "python3.12" # Using Python 3.12 runtime
  handler       = "create_read_replica.lambda_handler"
  role          = aws_iam_role.lambda_rds_role.arn

  # Use local Python script; Terraform will zip it automatically
  filename = "${path.module}/lambda_scripts/create_read_replica.py"

  # Environment variables passed to the function
  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER = aws_db_instance.db.id
    }
  }

  # Tags for identification
  tags = {
    Name        = "${var.name_prefix}-create-replica"
    Environment = var.environment
  }
}

# --- Lambda Function for Deleting Read Replicas --- #
# Define Lambda function to delete read replicas for RDS
resource "aws_lambda_function" "delete_read_replica" {
  function_name = "${var.name_prefix}-delete-replica"
  runtime       = "python3.12" # Using Python 3.12 runtime
  handler       = "delete_read_replica.lambda_handler"
  role          = aws_iam_role.lambda_rds_role.arn

  # Use local Python script; Terraform will zip it automatically
  filename = "${path.module}/lambda_scripts/delete_read_replica.py"

  # Environment variables passed to the function
  environment {
    variables = {
      REPLICA_IDENTIFIER = "${aws_db_instance.db.id}-replica-1"
    }
  }

  # Tags for identification
  tags = {
    Name        = "${var.name_prefix}-delete-replica"
    Environment = var.environment
  }
}

# --- Lambda Permission for Creating Read Replica --- #
resource "aws_lambda_permission" "allow_cloudwatch_create" {
  count         = var.read_replicas_count > 0 ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchCreate"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_create_replica_arn
  principal     = "events.amazonaws.com"
}

# --- Lambda Permission for Deleting Read Replica --- #
resource "aws_lambda_permission" "allow_cloudwatch_delete" {
  count         = var.read_replicas_count > 0 ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchDelete"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_delete_replica_arn
  principal     = "events.amazonaws.com"
}
