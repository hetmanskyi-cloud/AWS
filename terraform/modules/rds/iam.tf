# --- IAM Role for RDS Enhanced Monitoring --- #
# This file defines the IAM Role and Policy Attachment for enabling Enhanced Monitoring in RDS.
# Creates an IAM Role that allows RDS to send enhanced monitoring metrics to CloudWatch.
# The `assume_role_policy` grants RDS the permission to assume this IAM Role.
resource "aws_iam_role" "rds_monitoring_role" {
  count = var.enable_rds_monitoring ? 1 : 0 # Create role only if monitoring is enabled

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
# Attaches an AWS-managed policy for Enhanced Monitoring to the IAM Role.
# Note: It is possible to replace this policy with a custom policy for stricter permissions.

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  count = var.enable_rds_monitoring ? 1 : 0

  role       = try(aws_iam_role.rds_monitoring_role[0].name, null)                    # IAM role to attach the policy to.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole" # AWS-managed policy for Enhanced Monitoring.
}

# --- Notes --- #
# 1. The IAM Role is created only if `enable_rds_monitoring` is set to true.
# 2. The AWS-managed policy provides broad permissions for Enhanced Monitoring.
#    - It can be replaced with a custom policy for stricter security and tailored permissions.
# 3. The `assume_role_policy` is required for RDS to assume the role and send metrics to CloudWatch.
# 4. Tags are applied for easier resource identification and management.