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
      # Permissions for interacting with RDS
      {
        Effect = "Allow",
        Action = [
          "rds:CreateDBInstanceReadReplica", # Create a read replica
          "rds:DeleteDBInstance",            # Delete an RDS instance
          "rds:DescribeDBInstances"          # View details of RDS instances
        ],
        Resource = [
          # Main RDS instance
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${aws_db_instance.db.id}",
          # Any replicas of the main RDS instance
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${aws_db_instance.db.id}-replica-*"
        ]
      },
      # Permissions for managing network interfaces (ENIs) in the VPC
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",    # Create a network interface
          "ec2:DescribeNetworkInterfaces", # View details of network interfaces
          "ec2:DeleteNetworkInterface",    # Delete a network interface
          "ec2:AssignPrivateIpAddresses",  # Assign private IPs to the ENI
          "ec2:UnassignPrivateIpAddresses" # Unassign private IPs from the ENI
        ],
        Resource = "*" # Allow across all network interfaces
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_rds_policy_attachment" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = aws_iam_policy.lambda_rds_policy.arn
}

# --- Security Group for Lambda --- #
# Security group allowing Lambda functions to interact with RDS
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions interacting with RDS"
  vpc_id      = var.vpc_id

  # Allow inbound traffic from RDS security group
  ingress {
    from_port       = 3306 # MySQL port for RDS
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id] # Allow traffic only from RDS Security Group
    description     = "Allow MySQL traffic from RDS Security Group"
  }

  # Allow outbound traffic to RDS and necessary services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for Lambda"
  }

  tags = {
    Name        = "${var.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

# --- Lambda Function for Creating Read Replicas --- #
# Define Lambda function to create read replicas for RDS
resource "aws_lambda_function" "create_read_replica" {
  function_name = "${var.name_prefix}-create-replica"
  runtime       = "python3.12" # Using Python 3.12 runtime
  handler       = "create_read_replica.lambda_handler"
  role          = aws_iam_role.lambda_rds_role.arn

  # Use local Python script; Terraform will zip it automatically
  filename = "${path.module}/lambda_scripts/create_read_replica.zip"

  # Security group for Lambda
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids
  }

  # Environment variables passed to the function
  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER = aws_db_instance.db.id
      SNS_TOPIC_ARN          = var.sns_topic_arn
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
  filename = "${path.module}/lambda_scripts/delete_read_replica.zip"

  # Security group for Lambda
  vpc_config {
    security_group_ids = [aws_security_group.lambda_sg.id]
    subnet_ids         = var.private_subnet_ids
  }

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
