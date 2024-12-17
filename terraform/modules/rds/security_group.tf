# --- RDS Security Group Configuration --- #
# This file defines the Security Group for RDS instances, managing access control and traffic rules.

# --- Security Group for RDS --- #
# Creates a Security Group to control inbound and outbound traffic for RDS.
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg-${var.environment}" # Dynamic name for RDS Security Group.
  description = "Security group for RDS access"                # Describes the purpose of the Security Group.
  vpc_id      = var.vpc_id                                     # Specifies the VPC ID where the Security Group is created.

  # --- Ingress Rule (Inbound Traffic) --- #
  # Allows inbound database traffic on the specified port from EC2 instances.
  ingress {
    description     = "Allow inbound DB traffic from EC2 instances"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id] # Reference EC2 Security Group passed via variable.
  }

  # --- Egress Rule (Outbound Traffic) --- #
  # Allows all outbound traffic to ensure connectivity with external services.
  egress {
    description = "Allow all outbound traffic from RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Allows all protocols.
    cidr_blocks = ["0.0.0.0/0"] # Allows traffic to any destination.
  }

  # --- Tags for Resource Identification --- #
  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                # Environment tag for resource management.
  }
}

# --- Notes --- #
# 1. Ingress rules restrict access to the RDS instance by allowing traffic only from the specified EC2 Security Group.
# 2. Egress rules are open to ensure the RDS instance can communicate with external resources as needed.
# 3. The 'db_port' variable defines the database port (e.g., 3306 for MySQL) and is passed dynamically.
# 4. Tags are applied to ensure easy identification and management across environments.
# 5. Modify 'ec2_security_group_id' to allow access from specific Security Groups or resources.