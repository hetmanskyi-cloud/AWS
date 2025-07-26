#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euxo pipefail

# This script expects a single JSON input from stdin containing the vpn_endpoint_id and region.
# Example: {"vpn_endpoint_id": "cvpn-endpoint-12345", "region": "eu-west-1"}

# Read input JSON from stdin
eval "$(jq -r '@sh "export vpn_endpoint_id=\(.vpn_endpoint_id) region=\(.region)"')"

# Fetch the Network Interface IDs associated with the Client VPN endpoint.
ENI_IDS=$(aws ec2 describe-client-vpn-endpoints \
  --client-vpn-endpoint-ids "$vpn_endpoint_id" \
  --query 'ClientVpnEndpoints[0].AssociatedTargetNetworks[].NetworkInterfaceId' \
  --output text \
  --region "$region")

# If no ENIs are found, exit gracefully with an empty list of IPs.
if [ -z "$ENI_IDS" ]; then
  jq -n '{ "public_ips": "[]" }'
  exit 0
fi

# Fetch the Public IPs from the Network Interfaces and format them as a JSON array of CIDRs.
# Example output: ["52.58.10.20/32", "3.120.50.60/32"]
PUBLIC_IPS_JSON=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_IDS \
  --query 'NetworkInterfaces[].Association.PublicIp' \
  --output json \
  --region "$region" \
  | jq '[.[] | select(. != null) | . + "/32"]'
)

# Output the final result as a single JSON object that Terraform can parse.
# The keys of this object will be available as attributes in the data source.
jq -n --argjson ips "$PUBLIC_IPS_JSON" '{ "public_ips_json": $ips }'
