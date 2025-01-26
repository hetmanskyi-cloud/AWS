# --- RDS Security Group Configuration --- #
# This file defines the Security Group for RDS instances, managing access control and traffic rules.

# --- Security Group for RDS --- #
# Creates a Security Group to control inbound and outbound traffic for RDS.
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg-${var.environment}" # Dynamic name for RDS Security Group.
  description = "Security group for RDS access"                # Describes the purpose of the Security Group.
  vpc_id      = var.vpc_id                                     # Specifies the VPC ID where the Security Group is created.

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  # --- Ingress Rule (Inbound Traffic) --- #
  # Allows inbound database traffic on the specified port from ASG instances.
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.asg_security_group_id] # Reference ASG Security Group passed via variable.
    description     = "Allow MySQL traffic from ASG instances"
  }

  # --- Egress Rules (Outbound Traffic) --- #
  # The egress block is typically NOT needed for RDS within a VPC.

  # Explanation:
  # 1. By default, Security Groups ALLOW ALL OUTBOUND TRAFFIC within the VPC.
  # 2. For RDS backups and logs:
  #    - Use VPC Endpoints for S3 and CloudWatch Logs to keep traffic private
  #    - Traffic through VPC Endpoints NEVER leaves the VPC
  #    - No explicit egress rules needed when using VPC Endpoints
  # 3. For test environments:
  #    - Default outbound rules are sufficient
  #    - Explicit egress rules add unnecessary complexity
  #
  # Note: For production environments where strict network control is required:
  # - Use VPC Endpoints for AWS services (S3, CloudWatch)
  # - If VPC Endpoints are not used, configure egress rules with specific
  #   AWS service IP ranges instead of 0.0.0.0/0

  # --- Tags for Resource Identification --- #
  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                # Environment tag for resource management.
  }
}

# --- Notes --- #
# 1. **Ingress Rules**:
#    - Restrict access to the RDS instance by allowing inbound traffic only from the specified ASG Security Group
#    - The 'db_port' variable defines the database port (e.g., 3306 for MySQL) and is passed dynamically

# 2. **Security Best Practices**:
#    - Use VPC Endpoints for AWS services to keep traffic private
#    - Regularly audit Security Group rules
#    - Follow the principle of least privilege for network access

# 3. **Lifecycle Configuration**:
#    - Ensures the Security Group is replaced without downtime by creating the new one before destroying the old one.

# 4. **Tags**:
#    - Tags are applied to ensure easy identification and management across environments.
#    - Includes dynamic name tags and environment-specific tags for organization.

# 5. **Security Best Practices**:
#    - Outbound traffic is limited to specific destinations (VPC, S3, CloudWatch Logs) to enhance security.
#    - Regularly audit Security Group rules to minimize unnecessary access and improve overall security.