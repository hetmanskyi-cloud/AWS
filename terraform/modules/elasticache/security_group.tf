# --- ElastiCache Security Group Configuration --- #
# This file defines the Security Group for ElastiCache Redis, managing access control and traffic rules.

# --- Security Group for ElastiCache Redis --- #
# Creates a Security Group to control inbound and outbound traffic for ElastiCache Redis.
resource "aws_security_group" "redis_sg" {
  name        = "${var.name_prefix}-redis-sg-${var.environment}" # Dynamic name for the Redis Security Group.
  description = "Security group for ElastiCache Redis"           # Allows access only from ASG instances.
  vpc_id      = var.vpc_id                                       # Specifies the VPC ID where the Security Group is created.

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-sg-${var.environment}"
  })
}

# --- Security Group Rule for Redis Ingress from ASG --- #
# Allows Redis traffic from ASG instances
resource "aws_security_group_rule" "redis_ingress_from_asg" {
  security_group_id        = aws_security_group.redis_sg.id           # Security Group ID for the Redis instance.
  type                     = "ingress"                                # Ingress rule type.
  from_port                = var.redis_port                           # Port range for Redis traffic.
  to_port                  = var.redis_port                           # Port range for Redis traffic.
  protocol                 = "tcp"                                    # TCP protocol for Redis traffic.
  source_security_group_id = var.asg_security_group_id                # Security Group ID for the ASG.
  description              = "Allow Redis traffic from ASG instances" # Description for the rule.
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

# --- Notes --- #
# 1. **Ingress Rules**:
#    - Ingress rule to allow Redis traffic from ASG instances is defined as a separate 'aws_security_group_rule' resource.
#    - This rule restricts access to the ElastiCache Redis, allowing inbound traffic only from the specified ASG Security Group.
#    - The 'redis_port' variable defines the Redis port (e.g., 6379) and is passed dynamically.

# 2. **Egress Rules**:
#    - Default egress rules are used, allowing all outbound traffic within the VPC.  Explicit egress rules are generally not required for ElastiCache within a VPC.

# 3. **Security Best Practices**:
#    - Use VPC Endpoints for AWS services to keep traffic private (if applicable для ElastiCache related services, though less common for Redis itself).
#    - Regularly audit Security Group rules.
#    - Follow the principle of least privilege for network access.
# 4. **Port Configuration:**
#    - Redis typically runs on port 6379, but the value is configurable via `redis_port` to support non-default ports if needed.
