# --- Endpoints Security Group Configuration --- #
# This file defines the Security Group for the Interface VPC Endpoints,
# allowing controlled access from within the VPC.

# --- Security Group for VPC Endpoints --- #
# Creates a Security Group to control access for Interface Endpoints within the VPC.
resource "aws_security_group" "endpoints_sg" {
  count = var.enable_interface_endpoints ? 1 : 0

  name_prefix = "${var.name_prefix}-endpoints-sg-${var.environment}"
  description = "Security Group for VPC Endpoints allowing HTTPS access from VPC CIDR"
  vpc_id      = var.vpc_id # ID of the VPC where the Security Group is created

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-endpoints-security-group-${var.environment}"
  })
}

# --- Ingress Rules (Inbound Traffic) --- #
# Allow HTTPS traffic (port 443) to the VPC Endpoints from the entire VPC CIDR.
resource "aws_security_group_rule" "https_ingress" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints_sg[0].id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  description       = "Allow HTTPS access from the entire VPC CIDR"
}

# --- Egress Rules (Outbound Traffic) --- #
# Allow HTTPS outbound traffic from the VPC Endpoints to all destinations (0.0.0.0/0).
# This is *required* for Interface VPC Endpoints to communicate with AWS services
# and PrivateLink endpoints outside of the VPC.
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "https_egress" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints_sg[0].id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS to all destinations"
}

# --- Notes --- #
# 1. This Security Group is used exclusively for the Interface VPC Endpoints created by this module.
# 2. Ingress rules allow HTTPS (port 443) traffic from entire VPC CIDR block.
# 3. Egress rules allow HTTPS (port 443) traffic to all AWS services and PrivateLink endpoints.
# 4. Tags are applied to ensure easy identification and management of the Security Group.
