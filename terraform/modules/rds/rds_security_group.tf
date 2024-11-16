# --- RDS Security Group Configuration --- #

resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg-${var.environment}" # Dynamic name for RDS security group
  description = "Security group for RDS access"                # Description of the security group
  vpc_id      = var.vpc_id                                     # VPC ID where the security group is created

  tags = {
    Name        = "${var.name_prefix}-rds-sg-${var.environment}" # Tag for identifying the security group
    Environment = var.environment                                # Environment tag
  }
}

# --- Ingress Rules (Inbound Traffic) --- #
# Allow inbound traffic on the database port from private and public subnets

# Private subnets
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_private" {
  count             = length(var.private_subnet_cidr_blocks)
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound DB traffic from private subnet ${count.index + 1}"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[count.index]
}

# Public subnets
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_public" {
  count             = length(var.public_subnet_cidr_blocks)
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound DB traffic from public subnet ${count.index + 1}"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.public_subnet_cidr_blocks[count.index]
}

# --- Egress Rules (Outbound Traffic) --- #
# Allow outbound traffic to private and public subnets

# Private subnets
resource "aws_vpc_security_group_egress_rule" "rds_egress_private" {
  count             = length(var.private_subnet_cidr_blocks)
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound DB traffic to private subnet ${count.index + 1}"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[count.index]
}

# Public subnets
resource "aws_vpc_security_group_egress_rule" "rds_egress_public" {
  count             = length(var.public_subnet_cidr_blocks)
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound DB traffic to public subnet ${count.index + 1}"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.public_subnet_cidr_blocks[count.index]
}
