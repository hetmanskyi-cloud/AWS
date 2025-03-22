# --- RDS Security Group Configuration --- #
# Defines the Security Group for RDS instances, managing network access control and traffic rules.

# --- Security Group for RDS --- #
# Creates a Security Group to control inbound and outbound network traffic for RDS instances within the VPC.
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg-${var.environment}" # Dynamic name for RDS Security Group.
  description = "Security group for RDS access"                # Description of the Security Group's purpose.
  vpc_id      = var.vpc_id                                     # VPC ID where the Security Group is created.

  lifecycle {
    create_before_destroy = true # Ensures new SG creation before old one is destroyed to prevent downtime during updates.
  }

  # Tags for Resource Identification
  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                # Environment tag for resource management.
  }
}

# --- Security Group Rule: Ingress from ASG --- #
# Allows inbound MySQL traffic to the RDS instance from instances within the Application Security Group (ASG).
resource "aws_security_group_rule" "rds_ingress_from_asg" {
  security_group_id        = aws_security_group.rds_sg.id             # Security Group ID for the RDS instance.
  type                     = "ingress"                                # Ingress rule type.
  from_port                = var.db_port                              # Port range for MySQL traffic (from variable).
  to_port                  = var.db_port                              # Port range for MySQL traffic (from variable).
  protocol                 = "tcp"                                    # TCP protocol for MySQL traffic.
  source_security_group_id = var.asg_security_group_id                # Security Group ID of the ASG (source of traffic).
  description              = "Allow MySQL traffic from ASG instances" # Allows MySQL connections from ASG instances.
}

# --- Egress Rules (Outbound Traffic) --- #
# Egress rules are typically not required for RDS Security Groups within a VPC.
# By default, Security Groups allow all outbound traffic.
# For RDS backups and logging to AWS services (S3, CloudWatch Logs), VPC Endpoints are recommended to keep traffic within the VPC, eliminating the need for explicit egress rules.
# For environments requiring strict outbound control, consider Network ACLs or custom egress rules.

# --- Notes --- #
# 1. **Ingress Rule for ASG Access**:
#    - Ingress is configured via 'aws_security_group_rule' to allow database traffic from the Application Security Group (ASG).
#    - This restricts access to the RDS instance, permitting inbound connections only from the specified ASG Security Group, enhancing security.
#    - 'var.db_port' dynamically defines the database port (e.g., 3306 for MySQL) for rule configuration.

# 2. **Security Best Practices**:
#    - Implement VPC Endpoints for AWS services (like S3, CloudWatch) to ensure RDS traffic for backups and logs remains within the VPC and enhances security posture.
#    - Regularly audit and review Security Group rules to adhere to the principle of least privilege and minimize unnecessary network access.

# 3. **Lifecycle Management**:
#    - 'create_before_destroy' lifecycle setting ensures zero-downtime Security Group updates by creating a replacement before deleting the existing one.

# 4. **Resource Tagging**:
#    - Tags are applied for consistent resource identification and simplified management across different environments.
#    - Includes dynamic name-based tags and environment-specific tags for improved organization and filtering.