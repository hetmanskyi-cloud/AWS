# --- ElastiCache Security Group Configuration --- #

# Security Group for ElastiCache Redis to manage access control
resource "aws_security_group" "redis_sg" {
  name        = "${var.name_prefix}-redis-sg-${var.environment}" # Dynamic name for ElastiCache security group
  description = "Security group for ElastiCache Redis"           # Description of the security group
  vpc_id      = var.vpc_id                                       # VPC ID where the security group is created

  # Ingress Rule: Allow traffic from EC2 instances
  ingress {
    description     = "Allow inbound Redis traffic from EC2 instances"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id] # Reference EC2 security group passed via variable
  }

  # Egress Rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic from ElastiCache"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic to any destination
  }

  # Tags for identification
  tags = {
    Name        = "${var.name_prefix}-redis-sg-${var.environment}" # Tag for identifying the security group
    Environment = var.environment                                  # Environment tag
  }
}
