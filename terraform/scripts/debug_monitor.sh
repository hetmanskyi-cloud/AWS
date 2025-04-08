#!/bin/bash

set -euo pipefail  # Fail on error, undefined vars, or pipeline errors

# Default input values
NAME_TAG="${1:-dev-asg-instance}"                         # EC2 instance Name tag to search for
REGION="${2:-${AWS_DEFAULT_REGION:-eu-west-1}}"           # AWS region (env var or default)
MAX_RETRIES=30                                            # Max attempts to find instance
SLEEP_INTERVAL=10                                         # Seconds to wait between retries

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for EC2 instance with tag Name=${NAME_TAG} to become available..."

# Try up to MAX_RETRIES to find a running instance by tag
for i in $(seq 1 "$MAX_RETRIES"); do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${NAME_TAG}" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "None" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found running instance: $INSTANCE_ID"
    break
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instance not ready yet. Retrying in ${SLEEP_INTERVAL}s... ($i/${MAX_RETRIES})"
  sleep "$SLEEP_INTERVAL"
done

# If no instance was found after retries, exit with error
if [[ -z "${INSTANCE_ID:-}" || "$INSTANCE_ID" == "None" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Instance not found after ${MAX_RETRIES} attempts. Exiting."
  exit 1
fi

# Start SSM session and tail logs
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SSM session and monitoring logs..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Press Ctrl+C to stop monitoring manually."

aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
  --document-name "AWS-StartInteractiveCommand" \
  --parameters 'command=["sudo tail -f /var/log/user-data.log /var/log/wordpress_install.log"]'

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring session completed. Exiting script."

# --- Notes --- #
# ✅ Purpose:
#   This script helps developers and DevOps engineers debug EC2-based WordPress deployment issues
#   by connecting to the instance using AWS SSM and streaming installation logs in real time.
#
# 📌 What it does:
#   - Searches for a running EC2 instance with a specific Name tag (default: dev-asg-instance)
#   - Waits up to MAX_RETRIES × SLEEP_INTERVAL (default: 30 × 10s = 5 min)
#   - Connects via AWS SSM Session Manager (no need for SSH / public IPs)
#   - Tails logs: /var/log/user-data.log and /var/log/wordpress_install.log
#
# ⚙️ Requirements:
#   - AWS CLI v2 installed and configured (via `aws configure`)
#   - Session Manager plugin installed (`session-manager-plugin`)
#   - EC2 instance must:
#     • have the SSM Agent running
#     • be in a public subnet (or reachable)
#     • have the correct IAM role with `ssm:StartSession`, `ssm:SendCommand`, etc.
#
# 🧪 Typical usage during testing/debug:
#     ./debug_monitor.sh                         # Uses default tag and region
#     ./debug_monitor.sh dev-asg-instance eu-west-1
#
# ❗ Important:
#   - Designed for DEV and STAGE use. For production, logs should be monitored via CloudWatch Logs.
#   - Can be useful for inspecting logs without logging in manually or checking CloudWatch UI.