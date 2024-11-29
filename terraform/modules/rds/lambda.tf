# --- CloudWatch Log Group --- #

# CloudWatch Log Group for Lambda Function Logs
# Used to store logs from Lambda functions for debugging and monitoring
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-create-replica" # Log group name based on Lambda function name
  retention_in_days = 7                                               # Retain logs for 7 days (development-friendly)
}

# --- Security Group for Lambda --- #

# Security Group for Lambda Functions to interact with RDS
# Allows Lambda to access RDS over MySQL port (3306)
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions interacting with RDS"
  vpc_id      = var.vpc_id

  # Inbound rules (Ingress)
  ingress {
    from_port       = 3306 # Allow MySQL port
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id] # Allow traffic only from RDS security group
    description     = "Allow MySQL traffic from RDS Security Group"
  }

  # Outbound rules (Egress)
  egress {
    from_port   = 0 # Allow all outbound traffic
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Unrestricted destination
    description = "Allow all outbound traffic for Lambda"
  }

  tags = {
    Name        = "${var.name_prefix}-lambda-sg" # Tag for security group
    Environment = var.environment                # Environment-specific tagging
  }
}

# --- Lambda Function for Creating Read Replicas --- #

# Lambda Function to create RDS read replicas
resource "aws_lambda_function" "create_read_replica" {
  function_name = "${var.name_prefix}-create-replica"  # Function name
  runtime       = "python3.12"                         # Runtime version for the function
  handler       = "create_read_replica.lambda_handler" # Entry point for Lambda function
  role          = aws_iam_role.lambda_rds_role.arn     # IAM role for Lambda execution
  timeout       = 10                                   # Function timeout in seconds

  # Path to the zipped Python script for the function
  filename = "${path.module}/lambda_scripts/create_read_replica.zip"

  # Security group and subnets for the Lambda function
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids # Deploy Lambda in private subnets
  }

  # Environment variables for Lambda function
  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER = aws_db_instance.db.identifier            # Main RDS instance identifier
      SNS_TOPIC_ARN          = var.sns_topic_arn                        # SNS topic for notifications
      DYNAMODB_TABLE_NAME    = aws_dynamodb_table.replica_tracking.name # DynamoDB table for replica tracking
    }
  }

  depends_on = [ # Dependencies to ensure proper execution order
    aws_cloudwatch_log_group.lambda_logs,
    aws_db_instance.db,
    aws_dynamodb_table.replica_tracking
  ]

  tags = {
    Name        = "${var.name_prefix}-create-replica"
    Environment = var.environment
  }
}

# --- Lambda Function for Deleting Read Replicas --- #

# Lambda Function to delete RDS read replicas
resource "aws_lambda_function" "delete_read_replica" {
  function_name = "${var.name_prefix}-delete-replica" # Function name
  runtime       = "python3.12"
  handler       = "delete_read_replica.lambda_handler" # Entry point for Lambda function
  role          = aws_iam_role.lambda_rds_role.arn
  timeout       = 10

  # Path to the zipped Python script for the function
  filename = "${path.module}/lambda_scripts/delete_read_replica.zip"

  # Security group and subnets for the Lambda function
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids # Deploy Lambda in private subnets
  }

  # Environment variables for Lambda function
  environment {
    variables = {
      REPLICA_IDENTIFIER  = "${var.db_instance_identifier}-replica-1" # Default replica identifier
      SNS_TOPIC_ARN       = var.sns_topic_arn                         # SNS topic for notifications
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.replica_tracking.name  # DynamoDB table for replica tracking
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_db_instance.db,
    aws_dynamodb_table.replica_tracking
  ]

  tags = {
    Name        = "${var.name_prefix}-delete-replica"
    Environment = var.environment
  }
}

# --- Lambda Permissions --- #

# Permissions for Lambda to be triggered by CloudWatch for creating replicas
resource "aws_lambda_permission" "allow_cloudwatch_create" {
  count         = var.read_replicas_count > 0 ? 1 : 0  # Create permission only if replicas are enabled
  statement_id  = "AllowExecutionFromCloudWatchCreate" # Unique statement ID
  action        = "lambda:InvokeFunction"              # Allow invocation of Lambda function
  function_name = aws_lambda_function.create_read_replica.arn
  principal     = "events.amazonaws.com" # Principal is CloudWatch Events
}

# Permissions for Lambda to be triggered by CloudWatch for deleting replicas
resource "aws_lambda_permission" "allow_cloudwatch_delete" {
  count         = var.read_replicas_count > 0 ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_read_replica.arn
  principal     = "events.amazonaws.com"
}
