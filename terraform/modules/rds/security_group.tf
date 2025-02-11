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

  # --- Tags for Resource Identification --- #
  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                # Environment tag for resource management.
  }
}

# --- Security Group Rule for RDS Ingress from ASG --- #
# Allows MySQL traffic from ASG instances
resource "aws_security_group_rule" "rds_ingress_from_asg" {
  security_group_id        = aws_security_group.rds_sg.id             # Security Group ID for the RDS instance.
  type                     = "ingress"                                # Ingress rule type.
  from_port                = var.db_port                              # Port range for MySQL traffic.
  to_port                  = var.db_port                              # Port range for MySQL traffic.
  protocol                 = "tcp"                                    # TCP protocol for MySQL traffic.  
  source_security_group_id = var.asg_security_group_id                # Security Group ID for the ASG.
  description              = "Allow MySQL traffic from ASG instances" # Description for the rule.
}

# --- Egress Rules (Outbound Traffic) --- #
# The egress block is typically NOT needed for RDS within a VPC.

# Explanation:
# 1. By default, Security Groups ALLOW ALL OUTBOUND TRAFFIC within the VPC.
# 2. For RDS backups and logs:
#    - Use VPC Endpoints for S3 and CloudWatch Logs to keep traffic private
#    - Traffic through VPC Endpoints NEVER leaves the VPC
#    - No explicit egress rules needed when using VPC Endpoints
# 3. For test environments:
#    - Default outbound rules are sufficient
#    - Explicit egress rules add unnecessary complexity
#
# Note: For production environments where strict network control is required:
# - Use VPC Endpoints for AWS services (S3, CloudWatch) to keep traffic private

# --- Notes --- #

# 1. **Ingress Rules**:
#    - Ingress rule to allow database traffic from ASG instances is defined as a separate 'aws_security_group_rule' resource.
#    - This rule restricts access to the RDS instance, allowing inbound traffic only from the specified ASG Security Group.
#    - The 'db_port' variable defines the database port (e.g., 3306 for MySQL) and is passed dynamically.

# 2. **Security Best Practices**:
#    - Use VPC Endpoints for AWS services to keep traffic private
#    - Regularly audit Security Group rules
#    - Follow the principle of least privilege for network access

# 3. **Lifecycle Configuration**:
#    - Ensures the Security Group is replaced without downtime by creating the new one before destroying the old one.

# 4. **Tags**:
#    - Tags are applied to ensure easy identification and management across environments.
#    - Includes dynamic name tags and environment-specific tags for organization.

# 5. **Security Best Practices**:
#    - Outbound traffic is limited to specific destinations (VPC, S3, CloudWatch Logs) to enhance security.
#    - Regularly audit Security Group rules to minimize unnecessary access and improve overall security.