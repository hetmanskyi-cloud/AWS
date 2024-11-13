# --- RDS Security Group Configuration --- #

# Define a Security Group for RDS to control inbound and outbound traffic
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
# Allow inbound traffic on the database port from each private subnet

# Allow access from the first private subnet
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_1" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound DB traffic from the first private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[0]
}

# Allow access from the second private subnet
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_2" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound DB traffic from the second private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[1]
}

# Allow access from the third private subnet
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_3" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound DB traffic from the third private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[2]
}

# --- Egress Rule (Outbound Traffic) --- #

# Allow outbound traffic to the first private subnet
resource "aws_vpc_security_group_egress_rule" "rds_egress_1" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound DB traffic to the first private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[0]
}

# Allow outbound traffic to the second private subnet
resource "aws_vpc_security_group_egress_rule" "rds_egress_2" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound DB traffic to the second private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[1]
}

# Allow outbound traffic to the third private subnet
resource "aws_vpc_security_group_egress_rule" "rds_egress_3" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound DB traffic to the third private subnet"
  from_port         = var.db_port
  to_port           = var.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.private_subnet_cidr_blocks[2]
}
