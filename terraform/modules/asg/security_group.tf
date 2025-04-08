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

# SSH Traffic — Strongly recommended to disable SSH in production and use SSM instead
resource "aws_security_group_rule" "allow_ssh" {
  count = var.enable_asg_ssh_access ? 1 : 0

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.ssh_allowed_cidr # Restrict to trusted IPs only (e.g., your office or VPN)

  security_group_id = aws_security_group.asg_security_group.id
  description       = "Allow SSH access for debugging. Disable in production."
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

# --- Egress Rules (Outbound Traffic) --- #

# Allow all outbound traffic — Required for internet access, package updates, SSM, CloudWatch, Secrets Manager, etc.
# WARNING: Allowing 0.0.0.0/0 is generally acceptable for production *if*:
# - Public subnet is used (instances have direct internet access)
# - VPC Endpoints are not configured for AWS service traffic
# - The application needs access to external APIs or downloads
# For hardened environments, consider replacing with restricted egress rules or use VPC Endpoints.
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "all_outbound" {
  security_group_id = aws_security_group.asg_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"                                           # All protocols
  cidr_blocks       = ["0.0.0.0/0"]                                  # checkov:skip=CKV_AWS_382: Required for EC2 outbound access to download packages, updates, external APIs
  description       = "Allow all outbound traffic for ASG instances" # Review before production deployment
}

# --- Outbound Rule for ASG to VPC Endpoints --- #
# Allows outbound HTTPS traffic from ASG instances to VPC Endpoints (e.g., SSM, CloudWatch).
# Enabled only if `enable_interface_endpoints = true`
resource "aws_security_group_rule" "allow_private_ssm_egress" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id        = aws_security_group.asg_security_group.id # ASG Security Group
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = var.vpc_endpoint_security_group_id # Security Group of VPC Endpoints
  description              = "Allow outbound HTTPS traffic from ASG instances to VPC Endpoints"
}

# --- Notes --- #
# 1. **Traffic Rules**:
#    - HTTP traffic (port 80) is always enabled for communication between ALB and ASG.
#    - HTTPS traffic (port 443) is enabled only if `enable_https_listener = true` in the ALB module.
#
# 2. **Outbound Traffic**:
#    - All outbound traffic (`0.0.0.0/0`) is allowed by default to enable internet access, SSM, CloudWatch, Secrets Manager, and system updates.
#    - This configuration is acceptable in production if:
#        * Instances are in public subnets (with direct internet access)
#        * VPC Endpoints are not used
#        * Applications need external API access or downloads
#    - For hardened environments, consider restricting egress to known CIDRs or AWS service endpoints.
#
# 3. **Security Considerations**:
#    - Review the `all_outbound` rule periodically to match your security posture.
#    - Use **least privilege** principles where applicable.
#    - If using VPC Endpoints, you can safely restrict public egress while retaining AWS service access.
#
# 4. **Future Readiness**:
#    - The VPC Interface Endpoints module is currently **disabled**, but the security group is ready for future use.
#    - If ASG instances are later moved to private subnets **without NAT Gateway**, enabling `enable_interface_endpoints`
#      will redirect traffic through private endpoints instead of the public internet.
#
# 5. **Instance Connectivity**:
#    - ASG instances must reach AWS APIs (SSM, CloudWatch, Secrets Manager, KMS) via HTTPS (port 443).
#    - The default egress rule ensures all of these services are reachable without VPC Endpoints.
#
# 6. **Production Recommendations**:
#    - In production, disable SSH ingress and rely exclusively on SSM for instance access.
#    - Monitor outbound usage and adjust rules if tighter controls are needed.
#    - Use VPC Endpoints and private subnets with care — test thoroughly to ensure all services remain reachable.