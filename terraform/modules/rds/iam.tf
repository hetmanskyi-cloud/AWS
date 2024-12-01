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
