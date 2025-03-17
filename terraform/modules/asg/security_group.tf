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

# SSH Traffic (consider disabling SSH and using SSM for production environments)
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

# --- Egress Rules (Outbound Traffic) --- #

# Allow all outbound traffic
# ASG instances need unrestricted outbound access for updates, application dependencies, and external communication.
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "all_outbound" {
  security_group_id = aws_security_group.asg_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"                                           # All protocols
  cidr_blocks       = ["0.0.0.0/0"]                                  # Allow traffic to all destinations
  description       = "Allow all outbound traffic for ASG instances" # Review before production deployment

  # Note: For testing environments, we allow all outbound traffic (0.0.0.0/0).
}

# --- Outbound Rule for ASG to AWS Services --- #
# Allows outbound HTTPS traffic from ASG instances to AWS public endpoints
# when Interface Endpoints are disabled (enable_interface_endpoints = false).
resource "aws_security_group_rule" "allow_ssm_public_egress" {
  count = var.enable_interface_endpoints ? 0 : 1

  security_group_id = aws_security_group.asg_security_group.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTPS traffic from ASG instances to AWS public services (SSM, CloudWatch, etc.)"
}

# --- Outbound Rule for ASG to VPC Endpoints --- #
# Allows outbound HTTPS traffic from ASG instances to VPC Endpoints (e.g., SSM, CloudWatch)
# when Interface Endpoints are enabled (enable_interface_endpoints = true).
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
#
# 1. **Traffic Rules**:
#    - HTTP traffic (port 80) is always enabled for communication between ALB and ASG.
#    - HTTPS traffic (port 443) is enabled only if `enable_https_listener = true` in the ALB module.
#
# 2. **Outbound Traffic**:
#    - All outbound traffic (`0.0.0.0/0`) is allowed for ASG instances by default for flexibility.
#    - Specific outbound rules for AWS services are dynamically adjusted based on `enable_interface_endpoints`:
#      - If `enable_interface_endpoints = false`, ASG instances use public AWS service endpoints.
#      - If `enable_interface_endpoints = true`, ASG instances use private VPC Endpoints.
#
# 3. **Security Considerations**:
#    - The `all_outbound` rule (`0.0.0.0/0`) is suitable for development but should be restricted in production.
#    - Consider using **least privilege access** by specifying only required outbound destinations.
#    - Regularly audit security group rules to minimize unnecessary access.
#
# 4. **Future Readiness**:
#    - The VPC Interface Endpoints module is currently **disabled** but is retained for future use.
#    - If ASG instances are later moved to private subnets **without NAT Gateway**, enabling `enable_interface_endpoints`
#      will automatically switch outbound traffic to private VPC Endpoints instead of public AWS APIs.
#
# 5. **Instance Connectivity**:
#    - ASG instances require outbound HTTPS (`443`) to AWS services for SSM, CloudWatch, and KMS.
#    - Ensure the appropriate outbound rule (`allow_ssm_public_egress` or `allow_private_ssm_egress`) is active.