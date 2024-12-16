# --- Security Group for the ALB --- #
# This security group defines inbound and outbound traffic rules for the Application Load Balancer (ALB).

resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-sg" # Security group name prefixed with the environment name.
  vpc_id      = var.vpc_id                  # VPC where the ALB resides.

  # --- Ingress Rules --- #
  # Allow HTTP traffic for redirect (stage/prod) or testing (dev)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses.
    description = "Allow HTTP traffic for redirect or testing"
  }

  # Allow HTTPS traffic only in stage and prod
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses.
    description = "Allow HTTPS traffic from anywhere (stage/prod)"
  }

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
    Name        = "${var.name_prefix}-alb-sg" # Human-readable name for the security group.
    Environment = var.environment             # Tag to identify the environment (dev, stage, prod).
  }
}

# --- Notes --- #
# 1. HTTP (port 80):
#    - Open in all environments to support redirects or testing.
#    - In stage/prod, HTTP requests are redirected to HTTPS by ALB.
#
# 2. HTTPS (port 443):
#    - Enabled only in stage and prod for secure traffic.
#    - Certificates must be valid in these environments.
#
# 3. Egress Rules:
#    - All outbound traffic is allowed to ensure ALB can respond to incoming requests.
#
# 4. Security Recommendations:
#    - Regularly review CIDR blocks for ingress rules to ensure they meet your security requirements.
#    - Monitor ALB logs for unexpected traffic patterns.