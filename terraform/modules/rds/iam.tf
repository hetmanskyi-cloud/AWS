# --- IAM Role for RDS Enhanced Monitoring --- #

# IAM Role for enabling Enhanced Monitoring in RDS
# Allows RDS to assume this role and send enhanced monitoring metrics to CloudWatch Logs
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.name_prefix}-rds-monitoring-role"

  # The assume role policy allows RDS to assume the role
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

# Attach the AmazonRDSEnhancedMonitoringRole managed policy
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- IAM Role for Lambda --- #

# IAM Role for Lambda functions that interact with RDS
resource "aws_iam_role" "lambda_rds_role" {
  name = "${var.name_prefix}-lambda-rds-role"

  # This assume role policy allows Lambda to assume the role
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-lambda-role"
    Environment = var.environment
  }
}

# --- Attach Policy for Lambda Role --- #

# IAM Policy that defines permissions for Lambda functions managing RDS replicas
resource "aws_iam_policy" "lambda_rds_policy" {
  name = "${var.name_prefix}-lambda-rds-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      # Permissions for RDS operations
      {
        "Effect" : "Allow",
        "Action" : [
          "rds:CreateDBInstanceReadReplica",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances"
        ],
        "Resource" : [
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${var.db_instance_identifier}",
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db/${var.db_instance_identifier}-replica-*"
        ]
      },
      # Permissions for EC2 network interfaces
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "*"
      },
      # Permissions for CloudWatch Logs
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.name_prefix}-*"
      },
      # Permissions for DynamoDB replica tracking
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${aws_dynamodb_table.replica_tracking.name}"
      }
    ]
  })
}

# Attach the custom policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_rds_policy_attachment" {
  role       = aws_iam_role.lambda_rds_role.name
  policy_arn = aws_iam_policy.lambda_rds_policy.arn
}
