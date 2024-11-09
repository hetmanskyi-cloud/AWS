# --- EC2 Security Group Configuration --- #
# This file defines the security group for EC2 instances, including rules for SSH access, HTTP/HTTPS traffic, 
# and other essential network configurations.

resource "aws_security_group" "ec2_security_group" {
  name_prefix = "${var.name_prefix}-ec2-sg"
  description = "Security Group for EC2 instances allowing HTTP, HTTPS, and SSH"
  vpc_id      = var.vpc_id # ID of the VPC where the Security Group is created

  tags = {
    Name        = "${var.name_prefix}-ec2-security-group"
    Environment = var.environment
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Define inbound rules to allow specific types of traffic to the EC2 instances.

# Allow SSH access (port 22) from specified IPs or ranges (recommended to limit this in production)
resource "aws_security_group_rule" "ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidrs # IP ranges allowed to access via SSH
  security_group_id = aws_security_group.ec2_security_group.id
  description       = "Allow SSH access"
}

# Allow HTTP access for web traffic (port 80)
resource "aws_security_group_rule" "ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Open to the internet
  security_group_id = aws_security_group.ec2_security_group.id
  description       = "Allow HTTP access"
}

# Allow HTTPS access for secure web traffic (port 443)
resource "aws_security_group_rule" "ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Open to the internet
  security_group_id = aws_security_group.ec2_security_group.id
  description       = "Allow HTTPS access"
}

# --- Egress Rules (Outbound Traffic) --- #

# --- Egress Rules --- #
# Allow all outbound traffic (adjust as necessary to restrict access)

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_security_group.id
  description       = "Allow all outbound traffic"
}