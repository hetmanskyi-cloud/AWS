# --- Certificate Authority (CA) Generation --- #
# This section creates a self-contained Public Key Infrastructure (PKI) using the tls provider.
# This internal CA is used exclusively for mutual authentication between the Client VPN endpoint and the clients.

# 1. Generate a private key for our new Certificate Authority.
#    This key is the foundation of our PKI.
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Create a self-signed root certificate for our CA using the private key.
#    This certificate acts as the ultimate source of trust.
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "client-vpn.ca.internal" # Internal, descriptive name for the CA
    organization = "Hetmanskyi"
  }

  validity_period_hours = 8760 # Valid for 1 year
  is_ca_certificate     = true # This flag is crucial to mark it as a CA certificate

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# --- Server Certificate Generation --- #
# This section creates a certificate for the AWS Client VPN endpoint (the server-side).

# 3. Generate a private key for the server.
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 4. Create a certificate signing request (CSR) for the server.
resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "server.client-vpn.internal" # Internal, descriptive name for the server
    organization = "Hetmanskyi"
  }
}

# 5. Issue a certificate for the server by signing the CSR with our internal CA.
#    This proves the server's identity to connecting clients.
resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # Valid for 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# --- Client Certificate Generation --- #
# This section creates a certificate for the end-user's client device.

# 6. Generate a private key for the client.
resource "tls_private_key" "client" {
  count     = var.authentication_type == "certificate" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 7. Create a certificate signing request (CSR) for the client.
resource "tls_cert_request" "client" {
  count           = var.authentication_type == "certificate" ? 1 : 0
  private_key_pem = tls_private_key.client[0].private_key_pem

  subject {
    common_name  = "client.client-vpn.internal" # Internal, descriptive name for the client
    organization = "Hetmanskyi"
  }
}

# 8. Issue a certificate for the client by signing the CSR with our internal CA.
#    This proves the client's identity to the server.
resource "tls_locally_signed_cert" "client" {
  count              = var.authentication_type == "certificate" ? 1 : 0
  cert_request_pem   = tls_cert_request.client[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # Valid for 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# --- Notes --- #
# 1. Automation with `tls` Provider:
#    - We use the `hashicorp/tls` provider to fully automate the creation of the certificate hierarchy.
#    - This avoids manual steps and ensures the PKI is managed as code.
#
# 2. Conditional Creation:
#    - The CA and Server certificate resources are created unconditionally, as the server certificate is
#      always required for TLS tunnel encryption, regardless of the user authentication method.
#    - The Client certificate resources are created conditionally (via `count`) only when
#      `var.authentication_type` is set to "certificate".
#
# 3. Certificate Hierarchy:
#    - The structure is a standard two-tier PKI: a self-signed Root CA that signs the server certificate
#      and, optionally, the client certificate.
#
# 4. Internal Naming:
#    - The `common_name` values are for descriptive purposes only and are not real DNS names.
#
# 5. Security of Private Keys:
#    - The generated private keys are stored in the Terraform state file. It is critical
#      that the state file is stored in a secure, access-controlled backend (e.g., S3 with encryption).
