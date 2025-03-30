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
# Description:
#   This script connects to a running EC2 instance in the Auto Scaling Group via AWS SSM
#   and monitors the WordPress deployment logs for debugging and deployment visibility.
#
# Prerequisites:
#   - AWS CLI v2 must be installed and configured (aws configure)
#   - Session Manager Plugin for AWS CLI must be installed
#
# Usage:
#   ./debug_monitor.sh [instance_name_tag] [aws_region]
#   - instance_name_tag: (optional) EC2 instance Name tag (default: dev-asg-instance)
#   - aws_region: (optional) AWS region (default: eu-west-1)