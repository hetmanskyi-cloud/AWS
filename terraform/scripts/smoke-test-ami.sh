# This script replicates the logic from the Ansible playbook 'smoke-test-ami.yml'
# to verify the baseline configuration and hardening of a Golden AMI candidate.

set -euxo pipefail

echo ">>> Running Golden AMI Smoke Tests..."

# --- 1. Test: UFW Firewall --- #
# This test verifies that the Uncomplicated Firewall (UFW) is active and properly configured.
echo "Verifying Firewall (UFW) status..."
UFW_STATUS=$(ufw status)
# Check if the firewall is running.
if ! echo "$UFW_STATUS" | grep -q "Status: active"; then
    echo "FAIL: UFW is not active!"
    exit 1
fi
# Check if the 'Nginx Full' profile (allowing HTTP/HTTPS) is enabled.
if ! echo "$UFW_STATUS" | grep -q "Nginx Full"; then
    echo "FAIL: UFW does not allow 'Nginx Full' profile."
    exit 1
fi
echo "PASS: UFW is active and allows Nginx Full."

# --- 2. Test: Required Packages --- #
# This test ensures that all essential hardening packages are installed.
echo "Verifying required packages are installed..."
for pkg in fail2ban ufw unattended-upgrades; do
    # Use dpkg -s to check the status of a package. Redirect output to /dev/null for a silent check.
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "FAIL: Package '$pkg' is not installed."
        exit 1
    fi
    echo "PASS: Package '$pkg' is installed."
done

# --- 3. Test: Running Services --- #
# This test verifies that critical services are running.
echo "Verifying required services are running..."
for svc in fail2ban unattended-upgrades ssh; do
    # Use systemctl is-active to check if a service is currently running.
    if ! systemctl is-active --quiet "$svc"; then
        echo "FAIL: Service '$svc' is not running."
        exit 1
    fi
    echo "PASS: Service '$svc' is running."
done

# --- 4. Test: Security Cleanup --- #
# This test ensures that no sensitive information was left behind in the AMI.
echo "Verifying security cleanup..."
# Check for any lines defining sensitive variables in /etc/environment. `grep` will exit with 0 if found, so we expect a non-zero exit code.
if grep -qE '^(DB_PASSWORD|REDIS_AUTH_TOKEN|WP_ADMIN_PASSWORD)=' /etc/environment; then
    echo "FAIL: Sensitive variables found in /etc/environment."
    exit 1
fi
echo "PASS: No sensitive variables found in /etc/environment."

# Check that the root user's bash history file does not exist.
if [ -f "/root/.bash_history" ]; then
    echo "FAIL: /root/.bash_history file exists."
    exit 1
fi
echo "PASS: /root/.bash_history is absent."

# --- 5. Test: Apt Cache Update --- #
# This test confirms that the package manager is still functional and can reach its repositories.
echo "Verifying apt cache can be updated..."
# Running apt-get update should complete without errors. Output is redirected to /dev/null as we only care about the exit code.
apt-get update >/dev/null

echo "PASS: apt-get update completed successfully."

# --- Final Message --- #
echo ">>> ALL SMOKE TESTS PASSED"

# --- Notes --- #
# Purpose:
#   This script runs a series of "smoke tests" to validate that a Golden AMI candidate has been
#   hardened and configured correctly by a script like `prepare-golden-ami.sh`.
#
# Execution:
#   - Run on an instance launched from a newly created Golden AMI to verify its integrity.
#   - Should be executed with root privileges.
#
# What it Verifies:
#   1. Firewall: Checks that UFW is active and allows Nginx traffic.
#   2. Packages: Ensures that essential security packages (`fail2ban`, `ufw`, etc.) are installed.
#   3. Services: Confirms that critical services (`fail2ban`, `ssh`, etc.) are running.
#   4. Cleanup: Verifies that no sensitive environment variables or bash history were left in the AMI.
#   5. Functionality: Ensures `apt-get update` can still run, confirming network/repo access.
