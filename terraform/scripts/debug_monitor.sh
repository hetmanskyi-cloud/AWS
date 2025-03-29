#!/bin/bash
# debug_monitor.sh
#
# Description:
#   This script connects to a running EC2 instance in the Auto Scaling Group via AWS SSM
#   and monitors the WordPress deployment logs for debugging and deployment visibility.
#
# Prerequisites:
#   - AWS CLI v2 must be installed and configured (aws configure)
#   - Session Manager Plugin for AWS CLI must be installed:
#     https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#     Install on Linux/macOS:
#       curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_amd64/session-manager-plugin.tar.gz" -o "session-manager-plugin.tar.gz"
#       tar -xvzf session-manager-plugin.tar.gz
#       sudo ./session-manager-plugin/install
#
# Usage:
#   ./debug_monitor.sh [instance_name_tag] [aws_region]
#   - instance_name_tag: (optional) EC2 instance Name tag (default: dev-asg-instance)
#   - aws_region: (optional) AWS region (default: eu-west-1)
#
# Example:
#   ./debug_monitor.sh dev-asg-instance eu-west-1

# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u),
# and fail if any command in a pipeline fails (-o pipefail)
set -euo pipefail

# Default values if not provided
NAME_TAG="${1:-dev-asg-instance}"
REGION="${2:-${AWS_DEFAULT_REGION:-eu-west-1}}"  # Check environment variable, fallback to default region

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Searching for a running instance with tag: Name=${NAME_TAG}"

# Retrieve the running instance ID with the specified Name tag
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME_TAG}" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [[ -z "$INSTANCE_ID" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No running instance found with tag Name=${NAME_TAG}"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found instance ID: $INSTANCE_ID"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SSM session and monitoring logs..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Press Ctrl+C to stop monitoring manually."

# Start SSM session and stream both user-data and WordPress installation logs
aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
  --document-name "AWS-StartInteractiveCommand" \
  --parameters 'command=["sudo tail -f /var/log/user-data.log /var/log/wordpress_install.log"]'

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring session completed. Exiting script."