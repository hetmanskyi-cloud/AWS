# --- OpenVPN Client Configuration Template --- #

client
dev tun
proto tcp
remote ${vpn_endpoint_dns_name} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
# CA certificate used to validate the VPN server
${ca_cert}
</ca>

<cert>
# Client certificate identifying the VPN client
${client_cert}
</cert>

<key>
# Client private key
${client_key}
</key>
