#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# --- ПРОВЕРКА И УСТАНОВКА ПЕРЕМЕННЫХ --- #
# Переменные из Launch Template
: "${DB_NAME:?Variable not set}"
: "${DB_USERNAME:?Variable not set}"
: "${DB_PASSWORD:?Variable not set}"
: "${DB_HOST:?Variable not set}"
: "${PHP_VERSION:=8.3}"
: "${REDIS_HOST:=}"
: "${REDIS_PORT:=6379}"
: "${AWS_LB_DNS:?Variable not set}"
: "${WP_TITLE:?Variable not set}"
: "${WP_ADMIN:?Variable not set}"
: "${WP_ADMIN_EMAIL:?Variable not set}"
: "${WP_ADMIN_PASSWORD:?Variable not set}"

# --- ОБЩИЕ НАСТРОЙКИ --- #
WORDPRESS_PATH="/var/www/html/wordpress"
LOG_FILE="/var/log/wordpress_install.log"
NGINX_CONFIG="/etc/nginx/sites-available/wordpress"

# --- ФУНКЦИИ --- #
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $1"
    exit 1
}

# Функция для установки пакетов
install_packages() {
    local packages=("$@")
    log "Устанавливаем пакеты: ${packages[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" || error "Ошибка установки пакетов"
    
    # Проверка установки
    for package in "${packages[@]}"; do
        # Проверяем статус установки через apt
        if ! apt list --installed 2>/dev/null | grep -q "^${package}/"; then
            # Для PHP-пакетов пробуем проверить без версии
            if [[ "$package" == php* ]] && apt list --installed 2>/dev/null | grep -q "^${package#php${PHP_VERSION}}"; then
                continue
            fi
            error "Пакет $package не установлен!"
        fi
    done
}

# Функция для проверки сервисов
check_service() {
    local service=$1
    systemctl is-active --quiet "$service" || error "Сервис $service не запущен!"
}

# Функция для проверки подключения к базе данных
check_mysql() {
    log "Проверяем подключение к MySQL..."
    mysql -h"${DB_HOST}" -u"${DB_USERNAME}" --password="${DB_PASSWORD}" -e "SELECT 1" &>/dev/null || 
        error "Ошибка подключения к MySQL!"
}

# Функция для настройки WordPress
configure_wordpress() {
    log "Настраиваем WordPress..."
    cd "$WORDPRESS_PATH"
    
    # Настройка wp-config.php
    sudo -u www-data wp config create \
        --dbname="${DB_NAME}" \
        --dbuser="${DB_USERNAME}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${DB_HOST}" \
        --force || error "Ошибка создания wp-config.php"
        
    # Дополнительные настройки WordPress
    local wp_configs=(
        "WP_DEBUG false --raw"
        "WP_AUTO_UPDATE_CORE minor --raw"
        "DISALLOW_FILE_EDIT true --raw"
    )
    
    # Если есть Redis, добавляем его настройки
    if [[ -n "${REDIS_HOST}" ]]; then
        wp_configs+=(
            "WP_REDIS_HOST '${REDIS_HOST}' --raw"
            "WP_REDIS_PORT ${REDIS_PORT} --raw"
            "WP_REDIS_TIMEOUT 1 --raw"
            "WP_REDIS_READ_TIMEOUT 1 --raw"
            "WP_REDIS_DATABASE 0 --raw"
        )
    fi
    
    # Применяем все настройки
    for config in "${wp_configs[@]}"; do
        sudo -u www-data wp config set $config
    done
}

# --- ОСНОВНОЙ СКРИПТ --- #
main() {
    # Подготовка системы
    log "Начало установки WordPress"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Обновление системы
    apt-get update -y || error "Ошибка обновления пакетов"
    
    # Установка необходимых пакетов
    install_packages nginx mysql-client "php${PHP_VERSION}-fpm" php-mysql php-xml \
                    php-mbstring php-curl php-redis unzip netcat-openbsd curl
    
    # Настройка Nginx
    log "Настраиваем Nginx..."
    
    # Удаляем дефолтный конфиг перед созданием нового
    rm -f /etc/nginx/sites-enabled/default
    
    cat > "$NGINX_CONFIG" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html/wordpress;
    index index.php index.html;
    server_name _;
    
    # Логи для отладки
    access_log /var/log/nginx/wordpress_access.log;
    error_log /var/log/nginx/wordpress_error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location = /healthcheck.php {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        allow all;
    }
    
    # Запрещаем доступ к скрытым файлам
    location ~ /\. {
        deny all;
    }
}
EOF
    
    sed -i "s/\${PHP_VERSION}/${PHP_VERSION}/g" "$NGINX_CONFIG"
    
    # Проверяем наличие каталога и создаем символическую ссылку
    if [ ! -d "/etc/nginx/sites-enabled" ]; then
        mkdir -p /etc/nginx/sites-enabled
    fi
    
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/wordpress
    rm -f /etc/nginx/sites-enabled/default
    
    # Проверяем конфигурацию
    nginx -t || error "Ошибка в конфигурации Nginx"
    
    # Перезапускаем Nginx для применения изменений
    systemctl restart nginx || error "Ошибка перезапуска Nginx"
    
    # Проверяем статус Nginx после перезапуска
    if ! systemctl is-active --quiet nginx; then
        error "Nginx не запустился после настройки"
    fi
    
    # Установка WordPress
    log "Устанавливаем WordPress..."
    curl -O https://wordpress.org/latest.zip || error "Ошибка загрузки WordPress"
    unzip -q latest.zip || error "Ошибка распаковки WordPress"
    rm -rf "$WORDPRESS_PATH"
    mkdir -p "$WORDPRESS_PATH"
    cp -r wordpress/* "$WORDPRESS_PATH/"
    rm -rf wordpress latest.zip
    
    # Настройка прав доступа
    log "Настраиваем права доступа..."
    chown -R www-data:www-data "$WORDPRESS_PATH"
    find "$WORDPRESS_PATH" -type d -exec chmod 755 {} \;
    find "$WORDPRESS_PATH" -type f -exec chmod 644 {} \;
    
    # Создаем директорию для загрузок
    mkdir -p "$WORDPRESS_PATH/wp-content/uploads"
    chown -R www-data:www-data "$WORDPRESS_PATH/wp-content"
    chmod -R 755 "$WORDPRESS_PATH/wp-content/uploads"
    
    # Проверяем наличие файлов WordPress
    if [ ! -f "$WORDPRESS_PATH/wp-load.php" ]; then
        error "WordPress файлы отсутствуют в $WORDPRESS_PATH"
    fi
    
    # Создаем тестовый PHP файл для проверки
    echo "<?php phpinfo(); ?>" > "$WORDPRESS_PATH/test.php"
    chown www-data:www-data "$WORDPRESS_PATH/test.php"
    chmod 644 "$WORDPRESS_PATH/test.php"
    
    # Проверяем работу PHP через curl
    if ! curl -s "http://localhost/test.php" | grep -q "PHP Version"; then
        error "PHP не работает корректно через Nginx"
    fi
    
    # Удаляем тестовый файл
    rm -f "$WORDPRESS_PATH/test.php"
    
    log "Nginx и WordPress настроены корректно"
    
    # Создаем файл для проверки здоровья
    echo '<?php echo "OK"; ?>' > "$WORDPRESS_PATH/healthcheck.php"
    chown www-data:www-data "$WORDPRESS_PATH/healthcheck.php"
    chmod 644 "$WORDPRESS_PATH/healthcheck.php"
    
    # Установка WP-CLI
    if ! command -v wp &> /dev/null; then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    fi
    
    # Настройка WordPress
    configure_wordpress
    
    # Установка WordPress если еще не установлен
    if ! HTTP_HOST=localhost sudo -u www-data wp core is-installed --path="$WORDPRESS_PATH"; then
        log "Устанавливаем WordPress core..."
        HTTP_HOST=localhost sudo -u www-data wp core install \
            --path="$WORDPRESS_PATH" \
            --url="http://${AWS_LB_DNS}" \
            --title="${WP_TITLE}" \
            --admin_user="${WP_ADMIN}" \
            --admin_password="${WP_ADMIN_PASSWORD}" \
            --admin_email="${WP_ADMIN_EMAIL}" \
            --skip-email || error "Ошибка установки WordPress"
            
        log "WordPress успешно установлен"
    else
        log "WordPress уже установлен"
    fi
    
    # Проверяем успешность установки
    if ! HTTP_HOST=localhost sudo -u www-data wp core is-installed --path="$WORDPRESS_PATH"; then
        error "Ошибка: WordPress не установлен после попытки установки"
    fi
    
    # Настройка Redis если доступен
    if [[ -n "${REDIS_HOST}" ]] && nc -z -w5 "${REDIS_HOST}" "${REDIS_PORT}"; then
        log "Настраиваем Redis..."
        sudo -u www-data wp plugin install redis-cache --activate
        sudo -u www-data wp redis enable
    fi
    
    # Перезапуск сервисов
    systemctl restart nginx php${PHP_VERSION}-fpm
    
    # Проверка работоспособности
    check_service nginx
    check_service "php${PHP_VERSION}-fpm"
    check_mysql
    
    log "Установка WordPress успешно завершена!"
}

# Запуск основного скрипта
main "$@"