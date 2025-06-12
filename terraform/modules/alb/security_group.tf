# --- Security Group for the ALB --- #
# This security group defines the base configuration for the ALB.
# It controls inbound traffic from the public internet and outbound traffic to targets.
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-sg-${var.environment}" # Security group name prefixed with the environment name.
  vpc_id      = var.vpc_id                  # VPC where the ALB resides.
  description = "Security group for ALB handling inbound and outbound traffic"

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg-${var.environment}"
  })
}

# --- Ingress Rule for HTTP --- #
# HTTP is enabled to allow redirecting users from HTTP to HTTPS.
# HTTPS is conditionally enabled based on 'enable_https_listener' variable and SSL certificate configuration.
# checkov:skip=CKV_AWS_260:Allowing public HTTP access intentionally for redirect to HTTPS or fallback access
resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  #tfsec:ignore:aws-vpc-no-public-ingress-sgr
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTP traffic for redirecting to HTTPS or serving plain HTTP if HTTPS is disabled"
}

# --- Ingress Rule for HTTPS --- #
resource "aws_security_group_rule" "alb_https" {
  count = var.enable_https_listener ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS traffic (enabled only if HTTPS listener is active)"

  # Note: 0.0.0.0/0 is required to allow public HTTPS access.
  # Ensure the SSL certificate provided via `certificate_arn` is valid and properly configured and tested in production.
  # The HTTPS listener depends on a valid SSL certificate to function correctly.
  # If SSL certificate is missing, var.enable_https_listener variable should be set to false
}

# --- Egress Rule for ALB --- #
# Allow all outbound traffic. 
# Required for ALB to forward requests to registered targets (e.g., ASG instances) and communicate with external services.
# checkov:skip=CKV_AWS_382:Allowing all outbound traffic is required for ALB to communicate with targets and AWS services
resource "aws_security_group_rule" "alb_egress_all" {
  security_group_id = aws_security_group.alb_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # "-1" allows all protocols.  
  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to all IP addresses.
  description = "Allow all outbound traffic for ALB"

  # Note: Allowing 0.0.0.0/0 is acceptable for testing purposes. 
  # For production, replace with AWS service prefixes for improved security.
}

# --- Notes --- #
# 1. HTTP (port 80):
#    - Always enabled to allow traffic for redirecting HTTP to HTTPS.
# 2. HTTPS (port 443):
#    - Enabled only if `enable_https_listener = true` via `aws_security_group_rule`.
#    - Requires a valid SSL certificate.
# 3. Egress Rules:
#    - All outbound traffic is allowed to ensure ALB can respond to incoming requests.
# 4. Security Recommendations:
#    - Regularly review CIDR blocks for ingress rules to ensure they meet your security requirements.
#    - Monitor ALB logs for unexpected traffic patterns.
#    - For production, consider limiting CIDR ranges instead of allowing 0.0.0.0/0 to reduce exposure.