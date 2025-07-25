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
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 7. Create a certificate signing request (CSR) for the client.
resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "client.client-vpn.internal" # Internal, descriptive name for the client
    organization = "Hetmanskyi"
  }
}

# 8. Issue a certificate for the client by signing the CSR with our internal CA.
#    This proves the client's identity to the server.
resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
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
#    - We are using the `hashicorp/tls` provider to fully automate the creation of a certificate hierarchy.
#    - This approach avoids manual steps with tools like `easy-rsa` and ensures that the entire
#      PKI is managed as code, being created with `terraform apply` and destroyed with `terraform destroy`.
#
# 2. Certificate Hierarchy:
#    - The structure is a standard two-tier PKI: a self-signed Root CA, which then signs
#      both the server and client certificates.
#    - This establishes a chain of trust that is private to our VPN setup.
#
# 3. Internal Naming:
#    - The `common_name` values (e.g., "server.client-vpn.internal") are for descriptive purposes only.
#    - They are not real DNS names and are used internally within the certificate's subject field
#      to easily identify its purpose.
#
# 4. Security of Private Keys:
#    - The generated private keys exist only within the Terraform state file.
#    - It is critical that the state file is stored in a secure, access-controlled backend (like S3 with encryption).
