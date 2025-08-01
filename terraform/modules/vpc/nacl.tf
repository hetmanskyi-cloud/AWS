# --- Network ACL Configuration --- #
# This file defines Network ACLs (NACLs) for controlling traffic in public and private subnets.
# NACLs are stateless packet filters that control inbound and outbound traffic at the subnet level.

# --- Public Network ACL Configuration --- #
# Definition of the public NACL for controlling inbound and outbound traffic in public subnets.

# checkov:skip=CKV2_AWS_1 Justification: All required subnet associations are defined below via aws_network_acl_association.*
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-nacl-${var.environment}"
  })
}

# --- Public NACL Rules --- #
# Allow inbound traffic for HTTP, HTTPS, SSH, and return traffic.

# Rules for public subnets controlling inbound traffic to ALB.
# These rules must remain open (0.0.0.0/0) for ALB to accept HTTP/HTTPS traffic.

# Rule for inbound HTTP traffic on port 80 for ALB
# tfsec:ignore:aws-ec2-no-public-ingress-acl
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id # NACL ID
  rule_number    = 100                            # Rule number
  egress         = false                          # false for ingress traffic
  protocol       = "tcp"                          # TCP protocol
  from_port      = 80                             # Start port
  to_port        = 80                             # End port
  cidr_block     = "0.0.0.0/0"                    # Allow from all IPs for ALB
  rule_action    = "allow"                        # Allow traffic
}

# Rule for inbound HTTPS traffic on port 443 for ALB
# tfsec:ignore:aws-ec2-no-public-ingress-acl This is required for the ALB to receive HTTPS traffic from the internet, which is necessary for web application
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
# SSH access is required for testing. In production, restrict this to a specific range.

# checkov:skip=CKV_AWS_232 Justification: SSH access is restricted via variable-defined CIDR
resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  from_port      = 22
  to_port        = 22
  cidr_block     = var.ssh_allowed_cidr[0] #tfsec:ignore:aws-ec2-no-public-ingress-acl
  rule_action    = "allow"
}

# Rule for inbound return traffic on ephemeral ports (1024-65535)
# Allowing ephemeral port traffic is necessary for standard TCP connections.

# checkov:skip=CKV_AWS_231 Justification: Wide port range is required for EC2 return traffic in dev/stage environment; not recommended for production
resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  from_port      = 1024
  to_port        = 65535
  cidr_block     = "0.0.0.0/0" #tfsec:ignore:aws-ec2-no-public-ingress-acl
  rule_action    = "allow"
}

# Rule for inbound NFS traffic on port 2049 for EFS
resource "aws_network_acl_rule" "public_inbound_nfs" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  from_port      = 2049
  to_port        = 2049
  cidr_block     = var.vpc_cidr_block # Allow traffic only from within VPC
  rule_action    = "allow"
}

# Optional: Allow ICMP (ping) for diagnostics
# resource "aws_network_acl_rule" "public_inbound_icmp" {
#   network_acl_id = aws_network_acl.public_nacl.id
#   rule_number    = 150
#   egress         = false
#   protocol       = "icmp"
#   from_port      = -1
#   to_port        = -1
#   cidr_block     = "0.0.0.0/0"
#   rule_action    = "allow"
# }

# Egress Rules: Allow all outbound traffic.

# Rule allowing all outbound traffic
# Required to allow unrestricted outbound communication for instances in public subnets.
# tfsec:ignore:aws-ec2-no-excessive-port-access
resource "aws_network_acl_rule" "public_outbound_allow_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = true        # true for egress traffic
  protocol       = "-1"        # All protocols
  cidr_block     = "0.0.0.0/0" # Allow to all IPs
  rule_action    = "allow"
}

# --- Private Network ACL Configuration --- #

# Definition of the private NACL for controlling traffic in private subnets.

# checkov:skip=CKV2_AWS_1 Justification: All required subnet associations are defined below via aws_network_acl_association.*
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-nacl-${var.environment}"
  })
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
  rule_number    = 210
  egress         = true
  protocol       = "tcp"
  from_port      = 6379
  to_port        = 6379
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Rule for outbound DNS traffic (ports 53 TCP)
# NACL rules for DNS (port 53) are required for DNS queries
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

# Rule for outbound DNS traffic (ports 53 UDP)
# NACL rules for DNS (port 53) are required for DNS queries
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

# Allow inbound HTTPS (port 443) from the entire VPC CIDR
resource "aws_network_acl_rule" "private_inbound_https_endpoints" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 250
  egress         = false
  protocol       = "tcp"
  from_port      = 443
  to_port        = 443
  cidr_block     = aws_vpc.vpc.cidr_block
  rule_action    = "allow"
}

# Rule for outbound SSM traffic (port 443) to VPC Endpoint
resource "aws_network_acl_rule" "private_outbound_ssm" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 260
  egress         = true
  protocol       = "tcp"
  from_port      = 443
  to_port        = 443
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

# --- Notes --- #
# 1. Public NACLs are configured to allow HTTP, HTTPS, and SSH traffic,
#    but these rules can be toggled via variables for enhanced security.
# 2. Private NACLs allow restricted access to resources like MySQL and Redis within the VPC.
# 3. Egress rules permit outbound traffic to DNS and ephemeral ports for normal operations.
# 4. ICMP rules are not included by default; add them if network diagnostics (ping, traceroute) are needed.
# 5. Ensure that NACLs are correctly associated with the intended subnets to avoid connectivity issues.
# 6. Regularly review NACL rules to maintain alignment with security best practices.
# 7. DNS rules explicitly allow port 53 (TCP/UDP) for name resolution.
# 8. Ephemeral port ranges (1024-65535) are allowed for return traffic and outbound connections.
# 9. NACL rule numbers are spaced by 10 or more for easy future expansion.
