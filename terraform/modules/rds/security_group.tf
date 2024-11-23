# --- RDS Security Group Configuration --- #

# Security Group for RDS to manage access control
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg-${var.environment}" # Dynamic name for RDS security group
  description = "Security group for RDS access"                # Description of the security group
  vpc_id      = var.vpc_id                                     # VPC ID where the security group is created

  # Ingress Rule: Allow traffic from EC2 instances
  ingress {
    description     = "Allow inbound DB traffic from EC2 instances"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id] # Reference EC2 security group passed via variable
  }

  # Egress Rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic from RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic to any destination
  }

  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Tag for identifying the security group
    Environment = var.environment                                # Environment tag
  }
}
