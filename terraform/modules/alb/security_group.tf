# --- Security Group for the ALB --- #

resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id

  # HTTP (80) - temporarily open to the world
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }

  # HTTPS (443) - open for future use
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
  }
}
