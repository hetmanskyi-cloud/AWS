# --- ElastiCache Security Group Configuration --- #
# This file defines the Security Group for ElastiCache Redis, managing access control and traffic rules.

# --- Security Group for ElastiCache Redis --- #
# Creates a Security Group to control inbound and outbound traffic for ElastiCache Redis.
resource "aws_security_group" "redis_sg" {
  name        = "${var.name_prefix}-redis-sg-${var.environment}" # Dynamic name for the Redis Security Group.
  description = "Security group for ElastiCache Redis"           # Describes the purpose of the Security Group.
  vpc_id      = var.vpc_id                                       # Specifies the VPC ID where the Security Group is created.

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  # --- Ingress Rule (Inbound Traffic) --- #
  # Allows inbound Redis traffic (port 6379) only from ASG instances defined by the referenced Security Group.
  # Note: Ensure the Redis port (default: 6379) matches the configuration in all dependent modules and services.
  ingress {
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [var.asg_security_group_id] # Reference the ASG Security Group.
    description     = "Allow Redis access from ASG instances"
  }

  # --- Egress Rule --- #

  # The egress block is typically NOT needed for ElastiCache within a VPC.

  # Explanation:
  # 1. By default, Security Groups ALLOW ALL OUTBOUND TRAFFIC within the VPC.
  # 2. ElastiCache instances only RESPOND to requests initiated by clients within the VPC.
  # 3. Therefore, no explicit egress rules are needed for standard ElastiCache operation.
  #
  # For Production Environments (rare cases where outbound restrictions are needed):
  # If your ElastiCache cluster needs to connect to resources OUTSIDE your VPC
  # (e.g., specific external services), ONLY THEN should you add an egress rule.
  # In such cases, restrict the egress rule to ONLY the necessary destination IP
  # addresses or CIDR blocks and the required ports.

  # --- Tags for Resource Identification --- #
  tags = {
    Name        = "${var.name_prefix}-redis-sg-${var.environment}" # Name tag for identifying the Security Group.
    Environment = var.environment                                  # Environment tag for resource management.
  }
}

# --- Notes --- #
# 1. The Security Group restricts inbound traffic to Redis (port 6379) from ASG instances specified by the 'asg_security_group_id'.
# 2. No explicit egress rules are needed as ElastiCache only responds to client requests within the VPC.
# 3. Tags ensure the Security Group is identifiable and manageable across environments.
# 4. Adjust 'redis_port' via input variables to match the Redis configuration if different from the default (6379).