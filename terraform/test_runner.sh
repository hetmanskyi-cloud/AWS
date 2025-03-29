#!/bin/bash
set -euo pipefail
export DEBUG=true
[ "${DEBUG:-false}" = "true" ] && set -x

echo "[*] Creating fake EC2 environment..."

# 1. Подготовка окружения
WORKDIR="./test_env"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"/{var/www/html,etc,tmp,tmp/log,usr/local/bin}
mkdir -p "$WORKDIR"/tmp/wp-cli-cache
chmod -R 755 "$WORKDIR"

# 2. Мокаем /etc/environment (как EC2)
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

# 3. Копируем скрипты и шаблоны
cp ./scripts/deploy_wordpress.sh "$WORKDIR/tmp/deploy_wordpress.sh"
cp ./templates/wp-config-template.php "$WORKDIR/tmp/wp-config-template.php"
chmod +x "$WORKDIR/tmp/deploy_wordpress.sh"

# 4. Переходим в окружение
cd "$WORKDIR"

echo "[*] Starting fake EC2 session..."
echo

# 5. Запускаем скрипт как будто это EC2 (подгружаем переменные)
sudo env -i HOME=/tmp bash --noprofile --norc -c '
  export PATH=/usr/bin:/bin
  source /etc/environment
  echo "[*] Running deploy_wordpress.sh locally..."
  bash /tmp/deploy_wordpress.sh
'

echo
echo "[✅] Local test complete. Output logs and wp-config.php are in test_env/var/www/html"