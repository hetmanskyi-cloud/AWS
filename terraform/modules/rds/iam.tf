# --- IAM Role for RDS Enhanced Monitoring --- #
# Defines the IAM Role and Policy Attachment required for enabling Enhanced Monitoring in RDS.
# This role allows RDS to send enhanced monitoring metrics to CloudWatch, providing deeper insights into database performance.
# This role should be enabled only in environments requiring deeper observability for RDS.
# Avoid enabling in dev/test unless metrics are actively monitored.
resource "aws_iam_role" "rds_monitoring_role" {
  count = var.enable_rds_monitoring ? 1 : 0 # Create IAM Role only if RDS Enhanced Monitoring is enabled via variable.

  name = "${var.name_prefix}-rds-monitoring-role" # Dynamic name for the IAM role, incorporating name prefix for uniqueness.

  # Assume role policy grants 'monitoring.rds.amazonaws.com' service permission to assume this IAM role.
  # This is necessary for RDS Enhanced Monitoring to work correctly.
  # This is a service principal for RDS Enhanced Monitoring, not for other RDS operations (e.g., backups, encryption).
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

  # Tags for resource identification and management.
  tags = {
    Name        = "${var.name_prefix}-rds-monitoring-role"
    Environment = var.environment
  }
}

# --- IAM Role Policy Attachment --- #
# Attaches the AWS-managed 'AmazonRDSEnhancedMonitoringRole' policy to the IAM Role.
# This policy grants the necessary permissions for RDS Enhanced Monitoring to send metrics to CloudWatch.
# Consider replacing with a custom policy for stricter security and adherence to the principle of least privilege.
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  count = var.enable_rds_monitoring ? 1 : 0 # Attach policy only if RDS Enhanced Monitoring is enabled.

  role = try(aws_iam_role.rds_monitoring_role[0].name, null) # IAM role to attach the policy to. Uses 'try' to handle conditional role creation.
  # Alternative: Use a custom policy with only necessary permissions such as logs:PutLogEvents, logs:CreateLogStream, etc.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole" # AWS-managed policy for RDS Enhanced Monitoring.
}

# --- Notes --- #
# 1. IAM Role for RDS Enhanced Monitoring is created conditionally based on the 'enable_rds_monitoring' variable.
# 2. The AWS-managed AmazonRDSEnhancedMonitoringRole policy provides broad permissions. If strict compliance is required, replace it with a custom IAM policy like:
#    {
#      "Effect": "Allow",
#      "Action": [
#        "logs:PutLogEvents",
#        "logs:CreateLogStream",
#        "logs:DescribeLogStreams"
#      ],
#      "Resource": "*"
#    }
# 3. Replace the managed policy with a custom IAM policy to restrict actions if your compliance or security requirements demand stricter control.
# 4. The 'assume_role_policy' is essential to allow the 'monitoring.rds.amazonaws.com' service to assume the created IAM Role and send metrics to CloudWatch.
# 5. Tags are applied for improved resource identification, organization, and management within AWS.
# 6. This role is not used for CloudWatch agent on EC2 or other forms of RDS monitoring. It is specific to the Enhanced Monitoring feature.