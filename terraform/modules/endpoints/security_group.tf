# --- Endpoints Security Group Configuration --- #
# This file defines the Security Group for Interface VPC Endpoints (SSM, EC2 Messages, SSM Messages),
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

# Allow HTTPS access from the first private subnet
resource "aws_vpc_security_group_ingress_rule" "https_ingress_1" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[0]
  description       = "Allow HTTPS access from the first private subnet"
}

# Allow HTTPS access from the second private subnet
resource "aws_vpc_security_group_ingress_rule" "https_ingress_2" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[1]
  description       = "Allow HTTPS access from the second private subnet"
}

# Allow HTTPS access from the third private subnet
resource "aws_vpc_security_group_ingress_rule" "https_ingress_3" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[2]
  description       = "Allow HTTPS access from the third private subnet"
}

# --- Egress Rules (Outbound Traffic) --- #
# Allow all outbound traffic from the VPC Endpoints to external resources.

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.endpoints_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}

# --- Notes --- #
# 1. This Security Group is used exclusively for Interface VPC Endpoints (SSM, SSM Messages, EC2 Messages).
# 2. Ingress rules allow HTTPS (port 443) traffic only from private subnet CIDR blocks.
# 3. Egress rules permit unrestricted outbound traffic for Endpoint communication.
# 4. Tags are applied to ensure easy identification and management of the Security Group.