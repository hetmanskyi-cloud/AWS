# --- Client VPN Endpoint Security Group --- #
# This Security Group is attached directly to the Client VPN Endpoint's network interfaces.
# It controls the initial ingress for the VPN connection itself and egress towards the VPC.
resource "aws_security_group" "client_vpn" {
  name_prefix = "${var.name_prefix}-client-vpn-sg-${var.environment}"
  description = "Security Group for the Client VPN Endpoint"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-client-vpn-sg-${var.environment}"
  })
}

# --- Ingress Rule: Allow VPN Connections --- #
# Allows clients from the internet to establish a connection on the OpenVPN port (UDP/443).
resource "aws_security_group_rule" "allow_vpn_connections_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow inbound OpenVPN connections"
}

# --- Egress Rule: Allow All Outbound --- #
# Allows the VPN endpoint to forward traffic to any resource within the VPC and to the internet
# for return traffic to clients.
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"          # All protocols
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-egress-sgr
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow all outbound traffic from VPN endpoint"
}
