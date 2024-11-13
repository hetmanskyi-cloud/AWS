# --- Endpoints Security Group Configuration --- #
# This file defines the security group for interface VPC Endpoints (SSM, EC2 Messages, SSM Messages),
# allowing controlled access from all private subnets.

resource "aws_security_group" "endpoints_sg" {
  name_prefix = "${var.name_prefix}-endpoints-sg"
  description = "Security Group for VPC Endpoints allowing HTTPS access from private subnets"
  vpc_id      = var.vpc_id # ID of the VPC where the Security Group is created

  # Ensure the new security group is created before the old one is destroyed to avoid downtime
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.name_prefix}-endpoints-security-group"
    Environment = var.environment
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Define inbound rules to allow HTTPS traffic to the VPC Endpoints from each private subnet.

# Allow HTTPS access from the first private subnet (port 443)
resource "aws_vpc_security_group_ingress_rule" "https_ingress_1" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[0]
  description       = "Allow HTTPS access from the first private subnet"
}

# Allow HTTPS access from the second private subnet (port 443)
resource "aws_vpc_security_group_ingress_rule" "https_ingress_2" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[1]
  description       = "Allow HTTPS access from the second private subnet"
}

# Allow HTTPS access from the third private subnet (port 443)
resource "aws_vpc_security_group_ingress_rule" "https_ingress_3" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[2]
  description       = "Allow HTTPS access from the third private subnet"
}

# --- Egress Rules (Outbound Traffic) --- #
# Define outbound rules to allow all outbound traffic from the VPC Endpoints.

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.endpoints_sg.id
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}
