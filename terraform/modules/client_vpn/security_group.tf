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
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow inbound OpenVPN connections over TCP/443"
}

# --- Egress Rule: Allow All Outbound --- #
# Allows the VPN endpoint to forward traffic to any resource within the VPC and to the internet for return traffic to clients.
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"          # All protocols
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-egress-sgr
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow all outbound traffic from VPN endpoint"
}

# --- Notes --- #
# 1. Ingress:
#    - Port 443 is opened for TCP traffic from all sources (0.0.0.0/0).
#    - This matches the Client VPN endpoint configuration (transport_protocol = "tcp", vpn_port = 443).
#
# 2. Egress:
#    - All outbound traffic is allowed, ensuring that VPN clients can access both the VPC and the internet.
#
# 3. Security Considerations:
#    - Public ingress (0.0.0.0/0) is required for remote VPN clients, but should be tightly monitored.
#    - Rules are split into separate resources for clarity and to allow fine-grained lifecycle control.
#    - Ensure that the Client VPN endpoint is configured with appropriate authentication and authorization mechanisms.
