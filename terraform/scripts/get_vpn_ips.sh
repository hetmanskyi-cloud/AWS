#!/bin/bash

# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error.
set -euxo pipefail

# This script expects a single JSON input from stdin containing the vpn_endpoint_id and region.
# Example: {"vpn_endpoint_id": "cvpn-endpoint-12345", "region": "eu-west-1"}

# Read input JSON from stdin
eval "$(jq -r '@sh "export vpn_endpoint_id=\(.vpn_endpoint_id) region=\(.region)"')"

# --- START of additions to handle plan-time errors ---

# If the vpn_endpoint_id is empty or null (which can happen during plan), exit gracefully.
if [ -z "$vpn_endpoint_id" ]; then
  # Output a valid JSON with an empty list for Terraform to consume.
  jq -n '{ "public_ips_json": "[]" }'
  exit 0
fi

# Fetch the Network Interface IDs associated with the Client VPN endpoint.
# The `|| echo "None"` part prevents the script from exiting on error (`set -e`) if the endpoint is not found during `plan`.
ENI_IDS=$(aws ec2 describe-client-vpn-endpoints \
  --client-vpn-endpoint-ids "$vpn_endpoint_id" \
  --query 'ClientVpnEndpoints[0].AssociatedTargetNetworks[].NetworkInterfaceId' \
  --output text \
  --region "$region" || echo "None")

# If the command failed or returned "None", it means the resource doesn't exist yet.
# Exit gracefully with an empty list of IPs so `terraform plan` can succeed.
if [[ "$ENI_IDS" == "None" || -z "$ENI_IDS" ]]; then
  jq -n '{ "public_ips_json": "[]" }'
  exit 0
fi

# --- END of additions ---

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
# We pass the JSON string into another JSON object.
jq -n --arg ips "$PUBLIC_IPS_JSON" '{ "public_ips_json": $ips }'
