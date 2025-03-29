#!/bin/bash
set -euxo pipefail
export DEBUG=true
[ "${DEBUG:-false}" = "true" ] && set -x

echo "[*] Creating fake EC2 environment..."

# 1. Create local testing directory structure
WORKDIR="./test_env"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"/{var/www/html,etc,tmp,tmp/log,usr/local/bin}
mkdir -p "$WORKDIR/tmp/wp-cli-cache"
chmod -R 755 "$WORKDIR"

# 2. Emulate /etc/environment as used in EC2
cat <<EOF > "$WORKDIR/etc/environment"
DB_NAME=mydatabase
DB_USER=rds_admin
DB_PASSWORD=mysecretpass123
DB_HOST=127.0.0.1
DB_PORT=3306
PHP_VERSION=8.3
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
AWS_DEFAULT_REGION=eu-west-1
AWS_LB_DNS=localhost
WP_TITLE="My WordPress Site"
WP_ADMIN=admin
WP_ADMIN_PASSWORD=admin123
WP_ADMIN_EMAIL=admin@example.com
AUTH_KEY=dummy
SECURE_AUTH_KEY=dummy
LOGGED_IN_KEY=dummy
NONCE_KEY=dummy
AUTH_SALT=dummy
SECURE_AUTH_SALT=dummy
LOGGED_IN_SALT=dummy
NONCE_SALT=dummy
EOF

# 3. Copy deployment script and wp-config template from parent directory
cp ../deploy_wordpress.sh "$WORKDIR/tmp/deploy_wordpress.sh"
cp ../wp-config-template.php "$WORKDIR/tmp/wp-config-template.php"
chmod +x "$WORKDIR/tmp/deploy_wordpress.sh"

# 4. Change to the emulated environment
cd "$WORKDIR"

echo "[*] Starting fake EC2 session..."
echo

# 5. Simulate EC2 runtime and run the deployment script
sudo env -i HOME=/tmp PATH=/usr/bin:/bin bash --noprofile --norc -c '
  while IFS= read -r line; do
    export "$line"
  done < etc/environment

  echo "[*] Running deploy_wordpress.sh locally..."
  bash ./tmp/deploy_wordpress.sh
'

echo
echo "[*] Local test complete. Output logs and wp-config.php are available in: test_env/var/www/html"

# --- Notes --- #
# - This runner simulates a minimal EC2 environment to test deploy_wordpress.sh locally.
# - It allows you to validate changes to user-data logic without provisioning real infrastructure.
# - MySQL and Redis services must be mocked or reachable for full verification.
# - Intended for development and debugging purposes only. Not a replacement for integration testing.