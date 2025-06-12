#!/bin/bash

set -euo pipefail  # Fail on error, undefined vars, or pipeline errors

# Configuration: Input Parameters and Defaults
ENVIRONMENT="${1:-${ENVIRONMENT:-dev}}"             # 1st arg, or ENV var ENVIRONMENT, or default 'dev'
REGION="${2:-${AWS_DEFAULT_REGION:-eu-west-1}}"     # 2nd arg, or AWS_DEFAULT_REGION, or default

# By default, use your full real tag template (edit as needed for future change)
NAME_TAG="${NAME_TAG:-wordpress-asg-instance-${ENVIRONMENT}}" # Name tag is auto-formed as 'asg-instance-<env>'
MAX_RETRIES=30                                                # Max attempts to find instance
SLEEP_INTERVAL=10                                             # Seconds to wait between retries

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for EC2 instance with tag Name=${NAME_TAG} in region ${REGION}..."

# Main Loop: Search for Running Instance by Tag
for i in $(seq 1 "$MAX_RETRIES"); do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${NAME_TAG}" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text | awk '{print $1}')

  if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "None" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found running instance: $INSTANCE_ID"
    break
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instance not ready yet. Retrying in ${SLEEP_INTERVAL}s... ($i/${MAX_RETRIES})"
  sleep "$SLEEP_INTERVAL"
done

# Failure Handling
if [[ -z "${INSTANCE_ID:-}" || "$INSTANCE_ID" == "None" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Instance not found after ${MAX_RETRIES} attempts. Exiting."
  exit 1
fi

# Start SSM Session and Tail Logs
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SSM session and monitoring logs..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Press Ctrl+C to stop monitoring manually."

aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
  --document-name "AWS-StartInteractiveCommand" \
  --parameters 'command=["sudo tail -f /var/log/user-data.log /var/log/wordpress_install.log"]'

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring session completed. Exiting script."

# --- Notes --- #
# ✅ Purpose:
#   Debug/monitor WordPress EC2 deployment in any environment (dev, stage, prod) via AWS SSM.
#
# 📌 What it does:
#   - Waits for a running EC2 instance with a specific Name tag.
#   - Connects via SSM Session Manager (no SSH/public IP needed).
#   - Tails logs: /var/log/user-data.log and /var/log/wordpress_install.log in real time.
#
# ⚙️ Requirements:
#   - AWS CLI v2 + session-manager-plugin installed and configured.
#   - EC2 instance:
#       • SSM Agent running and IAM role with SSM permissions.
#       • Must be reachable by SSM (usually public subnet or correct VPC endpoints).
#
# 🧪 Usage examples:
#   ./debug_monitor.sh                        # dev, Name=asg-instance-dev, region eu-west-1 (defaults)
#   ./debug_monitor.sh stage                  # stage, Name=asg-instance-stage, region eu-west-1
#   ./debug_monitor.sh prod eu-west-2         # prod, Name=asg-instance-prod, region eu-west-2
#   ENVIRONMENT=stage ./debug_monitor.sh      # via env var
#   NAME_TAG=my-custom-tag ./debug_monitor.sh # search by custom tag, any environment
#
# ❗ Important:
#   - For production use, prefer CloudWatch Logs for monitoring!
#   - This script is most useful in DEV/STAGE or for urgent troubleshooting.
#   - Ensure you have the necessary IAM permissions to use SSM and EC2 describe commands.