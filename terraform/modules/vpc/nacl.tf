# --- Network ACL Configuration --- #
# This configuration defines the Network ACLs (NACLs) for controlling traffic in public and private subnets.
#
# Public NACL:
# - Allows inbound traffic for web services (HTTP on port 80 and HTTPS on port 443).
# - Allows inbound SSH access (port 22) for remote management.
# - Allows all outbound traffic to simplify egress rules.
#
# Private NACL:
# - Allows inbound traffic for MySQL (port 3306) and ElastiCache (port 6379) within the VPC.
# - Allows all outbound traffic to simplify egress rules.
# - Restricts all other traffic to enhance security in private subnets, as per default NACL behavior.
#
# Each NACL is associated with the appropriate public or private subnets within the VPC.

# --- Public Network ACL Configuration --- #

# Public NACL for controlling inbound and outbound traffic for public subnets
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.vpc.id # Associate with the specified VPC

  tags = {
    Name        = "${var.name_prefix}-public-nacl"
    Environment = var.environment
  }
}

# --- Public NACL Rules --- #

# Ingress Rules: Allow inbound traffic for HTTP, HTTPS, SSH

# Rule: Allow inbound HTTP traffic on port 80
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  from_port      = 80
  to_port        = 80
  cidr_block     = "0.0.0.0/0" # Allow from any IP
  rule_action    = "allow"
}

# Rule: Allow inbound HTTPS traffic on port 443
resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  from_port      = 443
  to_port        = 443
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
}

# Rule: Allow inbound SSH traffic on port 22
resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  from_port      = 22
  to_port        = 22
  cidr_block     = "0.0.0.0/0" # Allow from any IP (consider restricting in production)
  rule_action    = "allow"
}

# Egress Rules: Allow all outbound traffic

# Allow all outbound traffic for public NACL
resource "aws_network_acl_rule" "public_outbound_allow_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"        # All protocols
  cidr_block     = "0.0.0.0/0" # Allow to all destinations
  rule_action    = "allow"     # Allow traffic
}

# --- Private Network ACL Configuration --- #

# Private NACL for controlling traffic within private subnets
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.vpc.id # Associate with the specified VPC

  tags = {
    Name        = "${var.name_prefix}-private-nacl"
    Environment = var.environment
  }
}

# --- Private NACL Rules --- #

# Ingress Rules: Allow MySQL and Redis traffic within VPC

# Rule: Allow inbound MySQL traffic on port 3306 within the VPC
resource "aws_network_acl_rule" "private_inbound_mysql" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  from_port      = 3306
  to_port        = 3306
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Rule: Allow inbound ElastiCache traffic on port 6379 within the VPC
# Note: Ensure that ElastiCache requires access on this port
resource "aws_network_acl_rule" "private_nacl_inbound_elasticache" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 210
  egress         = false
  protocol       = "tcp"
  from_port      = 6379
  to_port        = 6379
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Outbound Rules: Allow all outbound traffic

# Allow all outbound traffic for private NACL
resource "aws_network_acl_rule" "private_outbound_allow_all" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"        # All protocols
  cidr_block     = "0.0.0.0/0" # Allow to all destinations
  rule_action    = "allow"     # Allow traffic
}

# --- NACL Associations --- #

# Associate the Public NACL with the public subnets
resource "aws_network_acl_association" "public_nacl_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  network_acl_id = aws_network_acl.public_nacl.id
}

resource "aws_network_acl_association" "public_nacl_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  network_acl_id = aws_network_acl.public_nacl.id
}

resource "aws_network_acl_association" "public_nacl_association_3" {
  subnet_id      = aws_subnet.public_subnet_3.id
  network_acl_id = aws_network_acl.public_nacl.id
}

# Associate the Private NACL with the private subnets
resource "aws_network_acl_association" "private_nacl_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  network_acl_id = aws_network_acl.private_nacl.id
}

resource "aws_network_acl_association" "private_nacl_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  network_acl_id = aws_network_acl.private_nacl.id
}

resource "aws_network_acl_association" "private_nacl_association_3" {
  subnet_id      = aws_subnet.private_subnet_3.id
  network_acl_id = aws_network_acl.private_nacl.id
}
