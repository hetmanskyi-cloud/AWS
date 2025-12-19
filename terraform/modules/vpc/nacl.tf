# --- Network ACL Configuration --- #
# This file defines Network ACLs (NACLs) for controlling traffic in public and private subnets.
# NACLs are stateless packet filters that control inbound and outbound traffic at the subnet level.

locals {
  # Process the public NACL rules to replace the "VPC_CIDR" placeholder.
  processed_public_nacl_rules = {
    for k, v in var.public_nacl_rules : k => {
      rule_number = v.rule_number
      egress      = v.egress
      protocol    = v.protocol
      from_port   = v.from_port
      to_port     = v.to_port
      rule_action = v.rule_action
      cidr_block  = v.cidr_block == "VPC_CIDR" ? aws_vpc.vpc.cidr_block : v.cidr_block
    }
  }

  # Process the private NACL rules to replace the "VPC_CIDR" placeholder.
  processed_private_nacl_rules = {
    for k, v in var.private_nacl_rules : k => {
      rule_number = v.rule_number
      egress      = v.egress
      protocol    = v.protocol
      from_port   = v.from_port
      to_port     = v.to_port
      rule_action = v.rule_action
      cidr_block  = v.cidr_block == "VPC_CIDR" ? aws_vpc.vpc.cidr_block : v.cidr_block
    }
  }
}

# --- Public Network ACL Configuration --- #
# Definition of the public NACL for controlling inbound and outbound traffic in public subnets.

resource "aws_network_acl" "public_nacl" {
  # checkov:skip=CKV2_AWS_1:This NACL is associated with subnets via aws_network_acl_association resources later in this file.
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-nacl-${var.environment}"
  })
}

# --- Dynamically Generated Public NACL Rules --- #
resource "aws_network_acl_rule" "public_rules" {
  for_each = local.processed_public_nacl_rules

  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# --- Private Network ACL Configuration --- #

# Definition of the private NACL for controlling traffic in private subnets.

resource "aws_network_acl" "private_nacl" {
  # checkov:skip=CKV2_AWS_1:This NACL is associated with subnets via aws_network_acl_association resources later in this file.
  vpc_id = aws_vpc.vpc.id # VPC ID to which the NACL is attached

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-nacl-${var.environment}"
  })
}

# --- Dynamically Generated Private NACL Rules --- #
resource "aws_network_acl_rule" "private_rules" {
  for_each = local.processed_private_nacl_rules

  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# --- NACL Associations --- #
# Associate NACLs with the corresponding subnets.

# Associate the public NACL with public subnets
resource "aws_network_acl_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.public_nacl.id
}

# Associate the private NACL with private subnets
resource "aws_network_acl_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.private_nacl.id
}

# --- Notes --- #
# 1. Public NACLs are configured to allow HTTP, and HTTPS traffic,
#    but these rules can be toggled via variables for enhanced security.
# 2. Private NACLs allow restricted access to resources like MySQL and Redis within the VPC.
# 3. Egress rules permit outbound traffic to DNS and ephemeral ports for normal operations.
# 4. ICMP rules are not included by default; add them if network diagnostics (ping, traceroute) are needed.
# 5. Ensure that NACLs are correctly associated with the intended subnets to avoid connectivity issues.
# 6. Regularly review NACL rules to maintain alignment with security best practices.
# 7. DNS rules explicitly allow port 53 (TCP/UDP) for name resolution.
# 8. Ephemeral port ranges (1024-65535) are allowed for return traffic and outbound connections.
# 9. NACL rule numbers are spaced by 10 or more for easy future expansion.
