# --- CloudWatch Log Groups --- #

# Log group for Lambda function responsible for creating RDS replicas
resource "aws_cloudwatch_log_group" "lambda_create_logs" {
  name              = "/aws/lambda/${var.name_prefix}-create-replica"
  retention_in_days = 7 # Retain logs for 7 days (suitable for development environment)
}

# Log group for Lambda function responsible for deleting RDS replicas
resource "aws_cloudwatch_log_group" "lambda_delete_logs" {
  name              = "/aws/lambda/${var.name_prefix}-delete-replica"
  retention_in_days = 7 # Retain logs for 7 days (suitable for development environment)
}

# --- Security Group for Lambda Functions --- #

# Security group allowing Lambda functions to access the RDS database
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions interacting with RDS"
  vpc_id      = var.vpc_id

  # Allow inbound MySQL traffic from the RDS security group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id]
    description     = "Allow MySQL traffic from RDS Security Group"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for Lambda"
  }

  tags = {
    Name        = "${var.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

# --- Lambda Function for Creating Read Replicas --- #

# Lambda function to create RDS read replicas
resource "aws_lambda_function" "create_read_replica" {
  count         = var.read_replicas_count                                # Create as many functions as the number of replicas
  function_name = "${var.name_prefix}-create-replica-${count.index + 1}" # Unique name for each function
  runtime       = "python3.12"                                           # Specify the Python runtime version
  handler       = "create_read_replica.lambda_handler"                   # Entry point for the Lambda function
  role          = aws_iam_role.lambda_rds_role.arn                       # IAM role with permissions for RDS operations
  timeout       = 10                                                     # Set the maximum execution time for the function

  # Path to the zipped Python script for creating replicas
  filename = "${path.module}/lambda_scripts/create_read_replica.zip"

  # VPC configuration for Lambda to access the RDS database
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id] # Use the Lambda-specific security group
    subnet_ids         = var.private_subnet_ids            # Deploy Lambda in private subnets
  }

  # Environment variables for the function
  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER = aws_db_instance.db.identifier            # RDS instance identifier
      REPLICA_INDEX          = count.index + 1                          # Index for the replica (1-based)
      SNS_TOPIC_ARN          = var.sns_topic_arn                        # SNS topic for notifications
      DYNAMODB_TABLE_NAME    = aws_dynamodb_table.replica_tracking.name # DynamoDB table name for tracking replicas
    }
  }

  # Ensure dependent resources are created first
  depends_on = [
    aws_cloudwatch_log_group.lambda_create_logs,
    aws_db_instance.db,
    aws_dynamodb_table.replica_tracking,
    aws_iam_role.lambda_rds_role,
    aws_iam_role_policy_attachment.lambda_rds_policy_attachment
  ]

  tags = {
    Name        = "${var.name_prefix}-create-replica-${count.index + 1}"
    Environment = var.environment
  }
}

# --- Lambda Function for Deleting Read Replicas --- #

# Lambda function to delete RDS read replicas
resource "aws_lambda_function" "delete_read_replica" {
  count         = var.read_replicas_count                                # Create as many functions as the number of replicas
  function_name = "${var.name_prefix}-delete-replica-${count.index + 1}" # Unique name for each function
  runtime       = "python3.12"                                           # Specify the Python runtime version
  handler       = "delete_read_replica.lambda_handler"                   # Entry point for the Lambda function
  role          = aws_iam_role.lambda_rds_role.arn                       # IAM role with permissions for RDS operations
  timeout       = 10                                                     # Set the maximum execution time for the function

  # Path to the zipped Python script for deleting replicas
  filename = "${path.module}/lambda_scripts/delete_read_replica.zip"

  # VPC configuration for Lambda to access the RDS database
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id] # Use the Lambda-specific security group
    subnet_ids         = var.private_subnet_ids            # Deploy Lambda in private subnets
  }

  # Environment variables for the function
  environment {
    variables = {
      REPLICA_IDENTIFIER  = "${aws_db_instance.db.identifier}-replica-${count.index + 1}" # Identifier for the replica
      SNS_TOPIC_ARN       = var.sns_topic_arn                                             # SNS topic for notifications
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.replica_tracking.name                      # DynamoDB table name for tracking replicas
    }
  }

  # Ensure dependent resources are created first
  depends_on = [
    aws_cloudwatch_log_group.lambda_delete_logs,
    aws_db_instance.db,
    aws_dynamodb_table.replica_tracking
  ]

  tags = {
    Name        = "${var.name_prefix}-delete-replica-${count.index + 1}"
    Environment = var.environment
  }
}

# --- Lambda Permissions --- #

# Permissions for creating replicas
resource "aws_lambda_permission" "allow_cloudwatch_create" {
  count         = var.read_replicas_count
  statement_id  = "AllowExecutionFromCloudWatchCreate-${count.index + 1}" # Unique statement ID for each function
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_read_replica[count.index].arn
  principal     = "events.amazonaws.com" # Allow invocation from CloudWatch Events
}

# Permissions for deleting replicas
resource "aws_lambda_permission" "allow_cloudwatch_delete" {
  count         = var.read_replicas_count
  statement_id  = "AllowExecutionFromCloudWatchDelete-${count.index + 1}" # Unique statement ID for each function
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_read_replica[count.index].arn
  principal     = "events.amazonaws.com" # Allow invocation from CloudWatch Events
}
