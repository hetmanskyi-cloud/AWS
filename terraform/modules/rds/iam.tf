# --- IAM Role for RDS Enhanced Monitoring --- #

# Define an IAM Role for RDS monitoring with necessary policies
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "monitoring.rds.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-rds-monitoring-role"
    Environment = var.environment
  }
}

# Attach the AmazonRDSEnhancedMonitoringRole policy for RDS monitoring
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- IAM Role for Lambda --- #
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
resource "aws_iam_policy" "lambda_rds_policy" {
  name = "${var.name_prefix}-lambda-rds-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Permissions for interacting with RDS
      {
        Effect = "Allow",
        Action = [
          "rds:CreateDBInstanceReadReplica",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances"
        ],
        Resource = [
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${var.db_instance_identifier}",
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${var.db_instance_identifier}-replica-*"
        ]
      },
      # Permissions for managing network interfaces
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      },
      # Permissions for CloudWatch Logs
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.name_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rds_policy_attachment" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = aws_iam_policy.lambda_rds_policy.arn
}