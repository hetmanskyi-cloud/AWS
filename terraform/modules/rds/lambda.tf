# --- CloudWatch Log Group --- #

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-create-replica"
  retention_in_days = 7
}

# --- Security Group for Lambda --- #

# Security Group for Lambda to interact with RDS
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions interacting with RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id]
    description     = "Allow MySQL traffic from RDS Security Group"
  }

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

# --- Lambda Function for Read Replicas --- #

# Lambda Function for Creating Read Replicas
resource "aws_lambda_function" "create_read_replica" {
  function_name = "${var.name_prefix}-create-replica"
  runtime       = "python3.12"
  handler       = "create_read_replica.lambda_handler"
  role          = aws_iam_role.lambda_rds_role.arn

  # Use local Python script
  filename = "${path.module}/lambda_scripts/create_read_replica.zip"

  # Security group for Lambda
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids
  }

  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER = aws_db_instance.db.id
      SNS_TOPIC_ARN          = var.sns_topic_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_db_instance.db
  ]

  tags = {
    Name        = "${var.name_prefix}-create-replica"
    Environment = var.environment
  }
}


# Lambda Function for Deleting Read Replicas
resource "aws_lambda_function" "delete_read_replica" {
  function_name = "${var.name_prefix}-delete-replica"
  runtime       = "python3.12"
  handler       = "delete_read_replica.lambda_handler"
  role          = aws_iam_role.lambda_rds_role.arn
  filename      = "${path.module}/lambda_scripts/delete_read_replica.zip"

  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_db_instance.db
  ]

  tags = {
    Name        = "${var.name_prefix}-delete-replica"
    Environment = var.environment
  }
}

# --- Lambda Permissions --- #

# Permissions for Lambda to create read replicas with CloudWatch
resource "aws_lambda_permission" "allow_cloudwatch_create" {
  count         = var.read_replicas_count > 0 ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_read_replica.arn
  principal     = "events.amazonaws.com"
}

# Permissions for Lambda to delete read replicas with CloudWatch
resource "aws_lambda_permission" "allow_cloudwatch_delete" {
  count         = var.read_replicas_count > 0 ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_read_replica.arn
  principal     = "events.amazonaws.com"
}
