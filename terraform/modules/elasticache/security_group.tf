# --- Security Group for ElastiCache --- #
resource "aws_security_group" "redis_sg" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.name_prefix}-redis-sg"
    Environment = var.environment
  }
}

# Ingress rules (разрешить доступ только с EC2)
resource "aws_security_group_rule" "redis_ingress" {
  type                     = "ingress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis_sg.id
  source_security_group_id = var.ec2_security_group_id
}

# Egress rules (исходящий трафик)
resource "aws_security_group_rule" "redis_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.redis_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}
