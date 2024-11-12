# --- Network ACL Configuration --- #
# This file defines Network ACLs (NACLs) for controlling traffic in public and private subnets.
# NACLs are stateless packet filters that control inbound and outbound traffic at the subnet level.

# --- Public Network ACL Configuration ---
# Definition of the public NACL for controlling inbound and outbound traffic in public subnets.

resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = {
    Name        = "${var.name_prefix}-public-nacl" # Name prefix for easy identification
    Environment = var.environment                  # Environment tag (dev, prod, etc.)
  }
}

# --- Public NACL Rules --- #
# Rules for the public NACL, defining which traffic is allowed or denied.

## Ingress Rules: Allow inbound traffic for HTTP, HTTPS, SSH, and return traffic.

# Rule for inbound HTTP traffic on port 80
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id # NACL ID
  rule_number    = 100                            # Rule number
  egress         = false                          # false for ingress traffic
  protocol       = "tcp"                          # TCP protocol
  from_port      = 80                             # Start port
  to_port        = 80                             # End port
  cidr_block     = "0.0.0.0/0"                    # Allow from all IPs
  rule_action    = "allow"                        # Allow traffic
}

# Rule for inbound HTTPS traffic on port 443
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

# Rule for inbound SSH traffic on port 22
resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  from_port      = 22
  to_port        = 22
  cidr_block     = "0.0.0.0/0" # It is recommended to restrict the IP range in production
  rule_action    = "allow"
}

# Rule for inbound return traffic on ephemeral ports (1024-65535)
resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  from_port      = 1024
  to_port        = 65535
  cidr_block     = "0.0.0.0/0" # Allow from all IPs
  rule_action    = "allow"
}

## Egress Rules: Allow all outbound traffic.

# Rule allowing all outbound traffic
resource "aws_network_acl_rule" "public_outbound_allow_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = true        # true for egress traffic
  protocol       = "-1"        # All protocols
  cidr_block     = "0.0.0.0/0" # Allow to all IPs
  rule_action    = "allow"
}

# --- Private Network ACL Configuration ---
# Definition of the private NACL for controlling traffic in private subnets.

resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = {
    Name        = "${var.name_prefix}-private-nacl" # Name prefix
    Environment = var.environment                   # Environment tag
  }
}

# --- Private NACL Rules --- #
# Rules for the private NACL, defining access to resources within the VPC.

## Ingress Rules: Allow inbound traffic for MySQL and Redis from within the VPC.

# Rule for inbound traffic on port 3306 (MySQL)
resource "aws_network_acl_rule" "private_inbound_mysql" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  from_port      = 3306
  to_port        = 3306
  cidr_block     = aws_vpc.vpc.cidr_block # Allow only within the VPC
  rule_action    = "allow"
}

# Rule for inbound traffic on port 6379 (Redis)
resource "aws_network_acl_rule" "private_inbound_elasticache" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 210
  egress         = false
  protocol       = "tcp"
  from_port      = 6379
  to_port        = 6379
  cidr_block     = aws_vpc.vpc.cidr_block # Allow only within the VPC
  rule_action    = "allow"
}

# Rule for inbound return traffic on ephemeral ports (1024-65535)
resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 220
  egress         = false
  protocol       = "tcp"
  from_port      = 1024
  to_port        = 65535
  cidr_block     = aws_vpc.vpc.cidr_block # Allow only within the VPC
  rule_action    = "allow"
}

# Egress Rules: Allow outbound traffic to the VPC and DNS ports.

# Rule for MySQL
resource "aws_network_acl_rule" "private_outbound_mysql" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 200 # Unique number
  egress         = true
  protocol       = "tcp"
  from_port      = 3306
  to_port        = 3306
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Rule for Redis (ElastiCache)
resource "aws_network_acl_rule" "private_outbound_elasticache" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 210 # Changed to a unique number
  egress         = true
  protocol       = "tcp"
  from_port      = 6379
  to_port        = 6379
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Rule for outbound DNS traffic (ports 53 TCP/UDP)
resource "aws_network_acl_rule" "private_outbound_dns_tcp" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 220
  egress         = true
  protocol       = "tcp"
  from_port      = 53
  to_port        = 53
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
}

resource "aws_network_acl_rule" "private_outbound_dns_udp" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 230
  egress         = true
  protocol       = "udp"
  from_port      = 53
  to_port        = 53
  cidr_block     = "0.0.0.0/0"
  rule_action    = "allow"
}

# Rule for outbound ephemeral ports (1024-65535) within the VPC
resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 240
  egress         = true
  protocol       = "tcp"
  from_port      = 1024
  to_port        = 65535
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# --- NACL Associations --- #
# Associate NACLs with the corresponding subnets.

## Associate the public NACL with public subnets
resource "aws_network_acl_association" "public_nacl_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id  # ID of the first public subnet
  network_acl_id = aws_network_acl.public_nacl.id # Public NACL ID
  depends_on     = [aws_network_acl.public_nacl]  # Dependency for proper creation order
}

resource "aws_network_acl_association" "public_nacl_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  network_acl_id = aws_network_acl.public_nacl.id
  depends_on     = [aws_network_acl.public_nacl]
}

resource "aws_network_acl_association" "public_nacl_association_3" {
  subnet_id      = aws_subnet.public_subnet_3.id
  network_acl_id = aws_network_acl.public_nacl.id
  depends_on     = [aws_network_acl.public_nacl]
}

## Associate the private NACL with private subnets
resource "aws_network_acl_association" "private_nacl_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id  # ID of the first private subnet
  network_acl_id = aws_network_acl.private_nacl.id # Private NACL ID
  depends_on     = [aws_network_acl.private_nacl]
}

resource "aws_network_acl_association" "private_nacl_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  network_acl_id = aws_network_acl.private_nacl.id
  depends_on     = [aws_network_acl.private_nacl]
}

resource "aws_network_acl_association" "private_nacl_association_3" {
  subnet_id      = aws_subnet.private_subnet_3.id
  network_acl_id = aws_network_acl.private_nacl.id
  depends_on     = [aws_network_acl.private_nacl]
}
