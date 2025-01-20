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
  # 1. Allows outbound traffic within the VPC for internal communication.
  # 2. Grants outbound access to S3 and CloudWatch Logs over HTTPS (port 443) for backups and monitoring.
  #    - Note: Access to S3 and CloudWatch is restricted to HTTPS (port 443) to enhance security.

  # Outbound traffic within the VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                 # Allows all protocols
    cidr_blocks = [var.vpc_cidr_block] # Restricts traffic to the VPC CIDR block
    description = "Allow outbound traffic within VPC"
  }

  # Outbound traffic to S3 and CloudWatch Logs (restricted to HTTPS)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"         # HTTPS traffic only
    cidr_blocks = ["0.0.0.0/0"] # Allows access to external resources (S3 and CloudWatch Logs)
    description = "Allow outbound traffic to S3 and CloudWatch Logs over HTTPS"
  }

  # --- Tags for Resource Identification --- #
  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                # Environment tag for resource management.
  }
}

# --- Notes --- #
# 1. **Ingress Rules**:
#    - Restrict access to the RDS instance by allowing inbound traffic only from the specified ASG Security Group.
#    - The 'db_port' variable defines the database port (e.g., 3306 for MySQL) and is passed dynamically.

# 2. **Egress Rules**:
#    - Allow outbound traffic within the VPC for internal communication, restricted to the VPC CIDR block.
#    - Allow outbound HTTPS traffic to S3 and CloudWatch Logs for backups and monitoring. Only HTTPS (port 443) is allowed to enhance security.
#    - **Important**: The current code allows traffic to `0.0.0.0/0` on port 443 for S3 and CloudWatch Logs. This is acceptable for a test environment but not for production.
#      - For production environments, consider using `aws_ip_ranges` to restrict access to the specific IP ranges of AWS services (e.g., S3 and CloudWatch Logs).

# 3. **Lifecycle Configuration**:
#    - Ensures the Security Group is replaced without downtime by creating the new one before destroying the old one.

# 4. **Tags**:
#    - Tags are applied to ensure easy identification and management across environments.
#    - Includes dynamic name tags and environment-specific tags for organization.

# 5. **Security Best Practices**:
#    - Outbound traffic is limited to specific destinations (VPC, S3, CloudWatch Logs) to enhance security.
#    - Regularly audit Security Group rules to minimize unnecessary access and improve overall security.