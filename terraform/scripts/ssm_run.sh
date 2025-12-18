#!/usr/bin/env bash
#
# Description:
#   A wrapper script to execute shell commands on an EC2 instance via AWS SSM Run Command.
#   It waits for the command to complete, fetches the full output, and exits with a
#   non-zero status code if the command fails, making it suitable for CI/CD pipelines.
#
# Usage:
#   ./ssm_run.sh <instance-id> "command1" "command2 with spaces" ...

set -euo pipefail

# --- 1. Argument Parsing --- #
# The first argument must be the EC2 instance ID. The script will exit if it's not provided.
INSTANCE_ID="${1:?Instance ID is a required argument.}"
shift # Removes the first argument, so $@ now contains only the commands to be executed.

# --- 2. Command Formatting --- #
# Convert all remaining arguments into a single JSON array string.
# This correctly handles commands with spaces and special characters.
# Example: "echo 'hello world'" "ls -l" -> ["echo 'hello world'", "ls -l"]
COMMANDS_JSON=$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "$@")

# --- 3. Send Command via SSM --- #
# Use 'aws ssm send-command' to execute the shell script on the target instance.
# The command ID is extracted for later use.
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=${COMMANDS_JSON}" \
  --query "Command.CommandId" \
  --output text)

# --- 4. Wait for Completion --- #
# Use the 'aws ssm wait command-executed' waiter to pause the script until the command finishes.
# If the waiter fails (e.g., timeouts), print a warning but continue, to ensure the final output is still fetched.
echo "Waiting for SSM command ${CMD_ID} to complete on ${INSTANCE_ID}..." >&2
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" || echo "SSM command waiter failed or timed out. Fetching final output regardless..." >&2

# --- 5. Fetch and Display Output --- #
# Retrieve the full invocation details, including Stdout, Stderr, status, and response code.
INVOCATION_JSON=$(aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "{Status:Status,ResponseCode:ResponseCode,Stdout:StandardOutputContent,Stderr:StandardErrorContent}" \
  --output json)

# Print the full JSON output to stdout. This is useful for logging in CI/CD or Makefiles.
echo "$INVOCATION_JSON"

# --- 6. Final Status Check --- #
# Parse the final status from the JSON output.
# Exit with an error if the command was not successful to ensure calling scripts (like 'make') fail correctly.
STATUS=$(echo "$INVOCATION_JSON" | python3 -c 'import json, sys; print(json.load(sys.stdin)["Status"])')
if [[ "$STATUS" != "Success" ]]; then
  echo "Error: SSM Command failed with status '$STATUS'." >&2
  exit 1
fi

# --- Notes --- #
# Purpose:
#   Provides a reliable, synchronous way to run commands on a remote instance using SSM,
#   capturing the full output and correctly propagating failure status.
#
# Why it's useful:
#   - CI/CD Integration: Standard `aws ssm send-command` is asynchronous. This script makes it synchronous.
#   - Error Handling: Exits with a non-zero status code on failure, which can halt a 'make' target or CI/CD pipeline.
#   - Robust Output: Captures and displays stdout and stderr separately, which is critical for debugging.
#   - Safe Command Handling: Correctly passes commands with spaces or special characters by formatting them as a JSON array.
#
# Requirements:
#   - AWS CLI configured with appropriate permissions (ssm:SendCommand, ssm:GetCommandInvocation, etc.).
#   - Python 3 to format the commands into JSON.
#   - The target EC2 instance must be managed by SSM.
