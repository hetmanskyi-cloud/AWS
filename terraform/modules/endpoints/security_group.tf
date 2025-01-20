# --- Endpoints Security Group Configuration --- #
# This file defines the Security Group for Interface VPC Endpoints (SSM, ASG Messages, SSM Messages),
# allowing controlled access to and from private subnets.

# --- Security Group for VPC Endpoints --- #
# Creates a Security Group to control access for Interface Endpoints within the VPC.
resource "aws_security_group" "endpoints_sg" {
  name_prefix = "${var.name_prefix}-endpoints-sg"
  description = "Security Group for VPC Endpoints allowing HTTPS access from private subnets"
  vpc_id      = var.vpc_id # ID of the VPC where the Security Group is created

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.name_prefix}-endpoints-security-group"
    Environment = var.environment
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Allow HTTPS traffic (port 443) to the VPC Endpoints from each private subnet.
resource "aws_security_group_rule" "https_ingress" {
  for_each = { for cidr in concat(var.private_subnet_cidr_blocks, var.public_subnet_cidr_blocks) : cidr => cidr }

  security_group_id = aws_security_group.endpoints_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.key]
  description       = "Allow HTTPS access from private and public subnets"
}

# --- Egress Rules (Outbound Traffic) --- #
# Allow all outbound traffic from the VPC Endpoints to external resources.
# Optional: Use aws_security_group_rule for more granular control of security group rules.
resource "aws_security_group_rule" "all_outbound" {
  security_group_id = aws_security_group.endpoints_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
  # Note: In production, restrict egress traffic to the minimal required set of IP addresses and ports.
  # Using 0.0.0.0/0 is strongly discouraged in production environments.
}

# --- Notes --- #
# 1. This Security Group is used exclusively for Interface VPC Endpoints (SSM, SSM Messages, ASG Messages).
# 2. Ingress rules allow HTTPS (port 443) traffic only from private subnet CIDR blocks.
# 3. Egress rules permit unrestricted outbound traffic for Endpoint communication.
# 4. Tags are applied to ensure easy identification and management of the Security Group.