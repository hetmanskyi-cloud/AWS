# --- Client VPN Module Outputs --- #

output "client_vpn_config" {
  description = "The rendered OpenVPN configuration file (.ovpn) for the client. Contains embedded certificates and keys."
  value       = data.template_file.config.rendered
  sensitive   = true # This output contains private keys and certificates and should be handled securely.
}

output "client_vpn_endpoint_id" {
  description = "The ID of the Client VPN endpoint."
  value       = aws_ec2_client_vpn_endpoint.endpoint.id
}

# --- Notes --- #
# 1. Usage:
#    - After a successful `terraform apply`, you can extract the configuration file with the command:
#      terraform output -raw client_vpn_config > client.ovpn
#    - The resulting `client.ovpn` file can be directly imported into the AWS Client VPN desktop application
#      or any other OpenVPN-compatible client.
#
# 2. Sensitivity:
#    - The output is marked as `sensitive = true` because it contains the client's private key.
#    - Avoid printing this output directly to the console in production environments. Treat the generated
#      `.ovpn` file as a secret.
