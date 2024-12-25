# --- EC2 Security Group Configuration --- #
# This file defines the Security Group for EC2 instances, with rules dynamically adjusted 
# for different environments (dev, stage, prod).

# --- Security Group Resource --- #
resource "aws_security_group" "ec2_security_group" {
  name_prefix = "${var.name_prefix}-ec2-sg"
  description = "Security Group for EC2 instances"
  vpc_id      = var.vpc_id # VPC ID where the Security Group is created

  # Lifecycle configuration for smooth updates
  lifecycle {
    create_before_destroy = true # Ensure no downtime during updates
  }

  tags = {
    Name        = "${var.name_prefix}-ec2-security-group" # Name tag for identification
    Environment = var.environment                         # Tag for environment (dev, stage, prod)
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Dynamically adjust rules for SSH, HTTP, and HTTPS traffic based on environment.

# Temporary SSH access (port 22)
# - Enabled in dev/stage for all IPs (`0.0.0.0/0`).
# - Restricted to specific IP ranges in prod via `ssh_allowed_ips` variable.
# Note: SSH will be automatically disabled in stage/prod using EventBridge after debugging.
resource "aws_security_group_rule" "ssh" {
  count = var.enable_ssh_access ? 1 : 0 # Enabled only if SSH access is allowed

  security_group_id = aws_security_group.ec2_security_group.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.environment == "prod" ? var.ssh_allowed_ips : ["0.0.0.0/0"]
  description       = "Allow SSH access (restricted in prod)"
}

# HTTP traffic (port 80)
# Allowed in dev/stage for testing purposes; disabled in prod.
resource "aws_security_group_rule" "http" {
  count = var.environment != "prod" ? 1 : 0 # Disabled in prod

  security_group_id = aws_security_group.ec2_security_group.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP traffic (dev/stage only)"
}

# HTTPS traffic (port 443)
# Allowed only in prod for secure communication.
resource "aws_security_group_rule" "https" {
  count = var.environment == "prod" ? 1 : 0 # Enabled only in prod

  security_group_id = aws_security_group.ec2_security_group.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS traffic (prod only)"
}

# --- Traffic from ALB to EC2 Instances --- #

# HTTP traffic from ALB to EC2 (dev/stage only)
# Purpose: Testing and development environments may not require HTTPS, allowing HTTP simplifies setup.
resource "aws_security_group_rule" "alb_http" {
  count = var.environment != "prod" ? 1 : 0 # Disabled in prod

  security_group_id        = aws_security_group.ec2_security_group.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  description              = "Allow HTTP traffic from ALB (dev/stage only)"
}

# HTTPS traffic from ALB to EC2 (prod only)
# Secure communication for production environments.
resource "aws_security_group_rule" "alb_https" {
  count = var.environment == "prod" ? 1 : 0 # Enabled only in prod

  security_group_id        = aws_security_group.ec2_security_group.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  description              = "Allow HTTPS traffic from ALB (prod only)"
}

# --- Egress Rules (Outbound Traffic) --- #
# Allow all outbound traffic
# Note: These rules can be tightened in the future if specific destinations are known.
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ec2_security_group.id
  ip_protocol       = "-1"        # All protocols
  cidr_ipv4         = "0.0.0.0/0" # Allow traffic to all destinations
  description       = "Allow all outbound traffic for EC2 instances"
}

# --- Notes --- #
# 1. **SSH Access**:
#    - Enabled in dev and stage for unrestricted IPs (`0.0.0.0/0`).
#    - Restricted in prod to trusted IP ranges via `ssh_allowed_ips` variable.
#    - Temporarily enabled for `instance_image` in stage/prod for maintenance or debugging.
#    - SSH access in stage/prod will be automatically disabled after debugging using EventBridge (planned).
#
# 2. **HTTP/HTTPS Rules**:
#    - HTTP allowed in dev and stage for testing purposes only.
#    - HTTPS enforced in prod for secure communication.
#
# 3. **Traffic from ALB**:
#    - HTTP traffic allowed from ALB to EC2 in dev/stage environments only.
#    - HTTPS traffic allowed from ALB to EC2 in prod.
#
# 4. **Outbound Traffic**:
#    - All outbound traffic is allowed for simplicity, ensuring no restrictions on external connectivity.
#
# 5. **Dynamic Configuration**:
#    - Rules dynamically adjust based on the `environment` variable (`dev`, `stage`, `prod`).
#    - Provides flexibility and ensures security requirements are met across different environments.
#
# 6. **Security Best Practices**:
#    - Always review and update `ssh_allowed_ips` in `terraform.tfvars` for production environments.
#    - Regularly audit the security group rules to minimize unnecessary access and reduce attack surface.
#    - Automate SSH management wherever possible to prevent accidental exposure.