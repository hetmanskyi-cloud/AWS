# --- EC2 Security Group Configuration --- #
# This file defines the security group for EC2 instances, including rules for SSH access, HTTP/HTTPS traffic, 
# and other essential network configurations.

resource "aws_security_group" "ec2_security_group" {
  name_prefix = "${var.name_prefix}-ec2-sg"
  description = "Security Group for EC2 instances allowing HTTP, HTTPS, and SSH"
  vpc_id      = var.vpc_id # ID of the VPC where the Security Group is created

  # Ensure the new security group is created before the old one is destroyed to avoid downtime
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.name_prefix}-ec2-security-group"
    Environment = var.environment
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Define inbound rules to allow specific types of traffic to the EC2 instances.

# Allow temporary SSH access (port 22) if SSH access is enabled
resource "aws_security_group_rule" "ssh" {
  count = var.enable_ssh_access ? 1 : 0

  security_group_id = aws_security_group.ec2_security_group.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Replace with a more limited range in a production environment
  description       = "Allow SSH access"
}

# Ingress rule for HTTP
# resource "aws_vpc_security_group_ingress_rule" "http" {
#  security_group_id = aws_security_group.ec2_security_group.id
#  from_port         = 80
#  to_port           = 80
#  ip_protocol       = "tcp"
#  cidr_ipv4         = "0.0.0.0/0"
#  description       = "Allow HTTP access"
# }

# Ingress rule for HTTPS
#resource "aws_vpc_security_group_ingress_rule" "https" {
#  security_group_id = aws_security_group.ec2_security_group.id
#  from_port         = 443
#  to_port           = 443
#  ip_protocol       = "tcp"
#  cidr_ipv4         = "0.0.0.0/0"
#  description       = "Allow HTTPS access"
# }

# --- Allow Traffic from ALB to EC2 Instances --- #

# Rule to allow HTTP traffic from the ALB Security Group to EC2 instances
# Note: Open to the world for WordPress setup. Restrict in production!
resource "aws_security_group_rule" "alb_http" {
  security_group_id        = aws_security_group.ec2_security_group.id # EC2 Security Group ID
  type                     = "ingress"                                # Ingress (inbound) rule
  from_port                = 80                                       # Allow HTTP traffic (port 80)
  to_port                  = 80                                       # End of port range (same as from_port)
  protocol                 = "tcp"                                    # Protocol: TCP
  source_security_group_id = var.alb_sg_id                            # Traffic allowed only from ALB Security Group
  description              = "Allow HTTP traffic from ALB"            # Description for easy identification
}

# Rule to allow HTTPS traffic from the ALB Security Group to EC2 instances
resource "aws_security_group_rule" "alb_https" {
  security_group_id        = aws_security_group.ec2_security_group.id # EC2 Security Group ID
  type                     = "ingress"                                # Ingress (inbound) rule
  from_port                = 443                                      # Allow HTTPS traffic (port 443)
  to_port                  = 443                                      # End of port range (same as from_port)
  protocol                 = "tcp"                                    # Protocol: TCP
  source_security_group_id = var.alb_sg_id                            # Traffic allowed only from ALB Security Group
  description              = "Allow HTTPS traffic from ALB"           # Description for easy identification
}

# --- Egress Rules (Outbound Traffic) --- #

# Egress rule to allow all outbound traffic
# All egress traffic is allowed for simplicity.
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ec2_security_group.id
  ip_protocol       = "-1"        # All protocols
  cidr_ipv4         = "0.0.0.0/0" # Allow to all destinations
  description       = "Allow all outbound traffic for EC2 instances"
}
