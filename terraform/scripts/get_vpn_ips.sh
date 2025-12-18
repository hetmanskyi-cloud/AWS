#!/bin/bash

# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error.
set -euxo pipefail

# This script expects a single JSON input from stdin containing the vpn_endpoint_id and region.
# Example: {"vpn_endpoint_id": "cvpn-endpoint-12345", "region": "eu-west-1"}

# Read input JSON from stdin
eval "$(jq -r '@sh "export vpn_endpoint_id=\(.vpn_endpoint_id) region=\(.region)"')"

# If the vpn_endpoint_id is empty or null (which can happen during plan), exit gracefully.
if [ -z "$vpn_endpoint_id" ]; then
  # Output a valid JSON with an empty list for Terraform to consume.
  jq -n '{ "public_ips_json": "[]" }'
  exit 0
fi

# Find Network Interface IDs by filtering on their description, which is tagged with the VPN Endpoint ID by AWS.
# Using a wildcard at the beginning makes the filter robust against changes in the description's prefix.
ENI_IDS=$(aws ec2 describe-network-interfaces \
  --filters "Name=description,Values=*${vpn_endpoint_id}" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text \
  --region "$region" || echo "None")

# If the command failed or returned no ENIs, it means the resource doesn't exist yet (e.g. during `plan`).
# Exit gracefully with an empty list of IPs so `terraform plan` can succeed.
if [[ "$ENI_IDS" == "None" || -z "$ENI_IDS" ]]; then
  jq -n '{ "public_ips_json": "[]" }'
  exit 0
fi

# Fetch the Public IPs from the discovered Network Interfaces and format them as a JSON array of CIDRs.
# Example output: "[\"52.58.10.20/32\", \"3.120.50.60/32\"]"
PUBLIC_IPS_JSON=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_IDS \
  --query 'NetworkInterfaces[].Association.PublicIp' \
  --output json \
  --region "$region" \
  | jq '[.[] | select(. != null) | . + "/32"]'
)

# Output the final result as a single JSON object that Terraform can parse.
# The keys of this object will be available as attributes in the data source.
jq -n --arg ips "$PUBLIC_IPS_JSON" '{ "public_ips_json": $ips }'

# --- Notes --- #
# Purpose:
#   This script is designed to be used as a Terraform `external` data source. It dynamically fetches
#   the public egress IP addresses associated with an AWS Client VPN endpoint.
#
# How it Works:
#   1. It receives a JSON object via stdin containing `vpn_endpoint_id` and `region`.
#   2. It finds the network interfaces (ENIs) tagged by AWS with that VPN endpoint ID.
#   3. It extracts the public IPs from those ENIs.
#   4. It formats the list of IPs as a JSON array of CIDR blocks (e.g., ["1.2.3.4/32"]).
#   5. It outputs a final JSON object `{"public_ips_json": "[\"1.2.3.4/32\"]"}` that Terraform can parse.
#
# Terraform Plan Safety:
#   The script is designed to be safe during the `terraform plan` phase. If the VPN endpoint doesn't
#   exist yet (and thus has no ID), the script receives a null `vpn_endpoint_id`, detects this,
#   and exits gracefully with a valid JSON structure containing an empty list. This prevents the
#   plan from failing.
