# --- ASG Security Group Configuration --- #
# This file defines the Security Group for ASG instances with dynamically adjusted rules. 

# --- Security Group Resource --- #
resource "aws_security_group" "asg_security_group" {
  name_prefix = "${var.name_prefix}-asg-sg"
  description = "Security Group for ASG instances"
  vpc_id      = var.vpc_id # VPC ID where the Security Group is created

  # Lifecycle configuration for smooth updates
  lifecycle {
    create_before_destroy = true # Ensure no downtime during updates
  }

  tags = {
    Name        = "${var.name_prefix}-asg-security-group" # Name tag for identification
    Environment = var.environment                         # Tag for environment (dev, stage, prod)
  }
}

# SSH Traffic
resource "aws_security_group_rule" "allow_ssh" {
  count = var.enable_asg_ssh_access ? 1 : 0

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.ssh_allowed_cidr # For better control, restrict SSH to specific IP ranges in prod

  security_group_id = aws_security_group.asg_security_group.id
  description       = "Allow SSH access from specified CIDR blocks"
}

# --- Traffic from ALB to ASG Instances --- #

# --- Ingress Rules (Inbound Traffic) --- #
# Rules for HTTP and HTTPS traffic.

# HTTP traffic (from ALB to ASG, port 80)
resource "aws_security_group_rule" "alb_http" {
  security_group_id        = aws_security_group.asg_security_group.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  description              = "Allow HTTP traffic from ALB to ASG"
}

# HTTPS traffic (from ALB to ASG, port 443)
resource "aws_security_group_rule" "alb_https" {
  count = var.enable_https_listener ? 1 : 0 # Enabled only if HTTPS listener is active on ALB

  security_group_id        = aws_security_group.asg_security_group.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  description              = "Allow HTTPS traffic from ALB to ASG"
}

resource "aws_security_group_rule" "rds_access" {
  security_group_id        = aws_security_group.asg_security_group.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.rds_security_group_id
  description              = "Allow MySQL traffic from ASG to RDS"
}

resource "aws_security_group_rule" "redis_access" {
  security_group_id        = aws_security_group.asg_security_group.id
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.redis_security_group_id
  description              = "Allow Redis traffic from ASG to Redis"
}

# --- Egress Rules (Outbound Traffic) --- #

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.asg_security_group.id
  ip_protocol       = "-1"                                           # All protocols
  cidr_ipv4         = "0.0.0.0/0"                                    # Allow traffic to all destinations
  description       = "Allow all outbound traffic for ASG instances" # Review before production deployment

}

# --- Notes --- #
# 1. **Traffic Rules**:
#    - HTTP traffic is always enabled for communication between ALB and ASG.
#    - HTTPS traffic is enabled only if `enable_https_listener` is set to `true` in the ALB module.
#
# 2. **Outbound Rules**:
#    - All outbound traffic is allowed for simplicity.
#
# 3. **Best Practices**:
#    - Regularly audit security group rules to minimize unnecessary access.
#    - Ensure ALB and ASG configurations align with application requirements.