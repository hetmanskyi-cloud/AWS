# --- IAM Role for RDS Enhanced Monitoring --- #
# This file defines the IAM Role and Policy Attachment for enabling Enhanced Monitoring in RDS.

# --- IAM Role for RDS Enhanced Monitoring --- #
# Creates an IAM Role that allows RDS to send enhanced monitoring metrics to CloudWatch.
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.name_prefix}-rds-monitoring-role" # Dynamic name for the IAM role.

  # Assume role policy grants permission for RDS to assume this IAM role.
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

  # Tags for resource identification.
  tags = {
    Name        = "${var.name_prefix}-rds-monitoring-role"
    Environment = var.environment
  }
}

# --- IAM Role Policy Attachment --- #
# Attaches the AWS-managed policy for Enhanced Monitoring to the IAM Role.
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name                                  # IAM role to attach the policy to.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole" # AWS-managed policy for Enhanced Monitoring.
}

# --- Notes --- #
# 1. This IAM Role enables Enhanced Monitoring for RDS, allowing detailed metrics to be sent to CloudWatch.
# 2. The 'AmazonRDSEnhancedMonitoringRole' is an AWS-managed policy with predefined permissions.
# 3. Tags are applied to the IAM role for better identification and resource management.
# 4. Enhanced Monitoring provides additional performance metrics beyond standard CloudWatch metrics, such as CPU, memory, and disk I/O.
# 5. This role must be referenced in the 'monitoring_role_arn' parameter of the RDS instance configuration.