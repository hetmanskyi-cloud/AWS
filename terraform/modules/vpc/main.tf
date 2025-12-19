# --- VPC Configuration --- #
# Main VPC configuration with CIDR block and DNS support enabled

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-${var.environment}"
  })
}

# --- Public Subnet Configurations --- #
# Dynamically create public subnets based on the public_subnets variable.
# Public subnets must have public IP assignment enabled for instances that require direct internet access.
resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130:This resource defines public subnets, where mapping a public IP on launch is intentional.
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true # tfsec:ignore:aws-ec2-no-public-ip-subnet
  availability_zone       = each.value.availability_zone

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-${each.key}-${var.environment}"
  })
}

# --- Private Subnet Configurations --- #
# Dynamically create private subnets based on the private_subnets variable.
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false
  availability_zone       = each.value.availability_zone

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-${each.key}-${var.environment}"
  })
}

# --- Default Security Group Restrictions --- #
# Restrict all inbound and outbound traffic for the default security group in the VPC.
# This ensures that no unintended traffic is allowed.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id # Associate with the created VPC

  # By default, AWS allows all traffic within the default security group.
  # This configuration removes all rules to enforce strict traffic control.
  # Remove all inbound and outbound rules to fully restrict traffic.
  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-default-sg-${var.environment}"
  })
}

# --- Notes --- #
# 1. The VPC is configured with both public and private subnets to support various workloads.
# 2. Public subnets allow internet access through the Internet Gateway (IGW).
# 3. Private subnets are isolated and do not have direct internet access or public IPs by default,
#    providing a secure environment for sensitive resources (e.g., databases).
# 4. All subnets and resources are tagged with a consistent naming convention for easy management.
# 5. Ensure `map_public_ip_on_launch` is enabled only for public subnets.
# 6. Default Security Group:
#    - The default security group for the VPC is restricted to avoid unintended access.
#    - It is recommended to use custom security groups for precise control over instance access.
# 7. VPC Flow Logs:
#    - Captures all traffic types for auditing and troubleshooting.
#    - Logs are sent to CloudWatch with KMS encryption.
#    - VPC Flow Logs are configured in vpc/flow_logs.tf
