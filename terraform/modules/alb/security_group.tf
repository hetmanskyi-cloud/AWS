# --- Security Group for the ALB --- #
# This security group defines the base configuration for the ALB.
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-sg" # Security group name prefixed with the environment name.
  vpc_id      = var.vpc_id                  # VPC where the ALB resides.

  # --- Egress Rules --- #
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # "-1" allows all protocols.
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to all IP addresses.
    description = "Allow all outbound traffic"
  }

  # --- Tags --- #
  tags = {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
  }
}

# --- Ingress Rule for HTTP --- #
resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP traffic for redirecting to HTTPS"
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