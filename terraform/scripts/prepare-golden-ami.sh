# This script replicates the logic from the Ansible playbook 'prepare-golden-ami.yml'
# for baseline server updates and security hardening.

# Exit immediately if a command exits with a non-zero status.
# Print each command to stdout before executing it.
# Fail on unset variables.
# Prevent errors in a pipeline from being masked.
set -euxo pipefail

# --- 1. Package Management & System Updates --- #

# Ensure all apt commands run non-interactively to prevent prompts during automated execution.
export DEBIAN_FRONTEND=noninteractive

# Update the apt package index to get the latest list of available packages.
echo ">>> Updating apt cache..."
apt-get update

# Upgrade all installed packages to their latest versions.
# --autoremove: Removes any packages that were automatically installed to satisfy dependencies but are now no longer needed.
# --purge: Removes configuration files along with the packages.
echo ">>> Upgrading all packages..."
apt-get -y dist-upgrade --autoremove --purge

# Install essential security and maintenance packages:
# - fail2ban: Scans log files and bans IPs that show malicious signs.
# - ufw: "Uncomplicated Firewall" for managing network rules.
# - unattended-upgrades: Automatically installs security updates.
echo ">>> Installing hardening packages (fail2ban, ufw, unattended-upgrades)..."
apt-get -y install fail2ban ufw unattended-upgrades

# --- 2. Firewall Configuration (UFW) --- #

# Allow inbound traffic for the 'Nginx Full' profile, which includes both HTTP (port 80) and HTTPS (port 443).
# This is necessary for the web server to be accessible.
echo ">>> Configuring UFW to allow HTTP/HTTPS..."
ufw allow 'Nginx Full'

# Enable the firewall. The --force flag is used to bypass the interactive prompt,
# making it suitable for automated scripts.
echo ">>> Enabling UFW..."
ufw --force enable

# --- 3. SSH Hardening --- #

# Create the /run/sshd directory with correct permissions. This is required for the
# Privilege Separation feature in modern OpenSSH versions to work correctly.
echo ">>> Ensuring /run/sshd directory exists..."
mkdir -p /run/sshd
chmod 0755 /run/sshd

# Find the line for 'PermitRootLogin' (commented or not) and replace it to explicitly disallow root login over SSH.
echo ">>> Disabling SSH root login..."
sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Find the line for 'PasswordAuthentication' and replace it to disallow password-based logins,
# enforcing the use of SSH keys, which is more secure.
echo ">>> Disabling SSH password authentication..."
sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Run the sshd daemon in test mode to validate the configuration file for any syntax errors before applying.
echo ">>> Validating sshd config..."
sshd -t

# Restart the SSH service to apply the new, hardened configuration.
echo ">>> Restarting SSH service..."
systemctl restart ssh

# --- 4. System Cleanup --- #

# Remove any lines from /etc/environment that define sensitive variables. This prevents secrets from being baked into the final AMI.
# The '|| true' ensures that the script doesn't fail if the file doesn't exist or `sed` finds no matches.
echo ">>> Cleaning up sensitive variables from /etc/environment..."
sed -i -E '/^(DB_PASSWORD|REDIS_AUTH_TOKEN|WP_ADMIN_PASSWORD)=/d' /etc/environment || true

# Delete the root user's command history to prevent any sensitive commands or credentials
# that may have been used during setup from being stored in the AMI.
echo ">>> Clearing root bash history..."
rm -f /root/.bash_history

# Perform a final cleanup of the package manager cache to reduce the AMI's final size.
echo ">>> Performing final apt cleanup..."
apt-get -y autoremove --purge
apt-get -y clean

# --- Final Message --- #
echo ">>> AMI preparation script finished successfully."
echo ">>> The final step in the Ansible playbook was a reboot."
echo ">>> You can trigger this manually by running: scripts/ssm_run.sh <INSTANCE_ID> 'reboot'"

# --- Notes --- #
# Purpose:
#   This script automates the hardening of a base Ubuntu EC2 instance to prepare it for use as a "Golden AMI".
#   It performs system updates, configures a firewall, secures the SSH daemon, and cleans up sensitive data.
#
# Execution:
#   - Typically run on a temporary EC2 instance that will be captured as an AMI.
#   - Should be executed with root privileges.
#
# Key Hardening Steps:
#   1. Updates all system packages to their latest versions.
#   2. Installs and enables UFW (Uncomplicated Firewall), allowing only Nginx traffic (HTTP/HTTPS).
#   3. Installs `fail2ban` for intrusion prevention and `unattended-upgrades` for automatic security patches.
#   4. Disables SSH root login and password authentication, enforcing key-based access.
#   5. Cleans up temporary files, package caches, and sensitive data (like bash history or env vars) to minimize the AMI footprint and enhance security.
