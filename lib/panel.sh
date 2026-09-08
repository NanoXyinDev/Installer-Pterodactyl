#!/usr/bin/env bash
set -euo pipefail
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
PANEL_DOMAIN=""
PANEL_DB_NAME=""
PANEL_DB_USER=""
PANEL_DB_PASS=""
PANEL_ADMIN_EMAIL=""
PANEL_ADMIN_USER=""
PANEL_ADMIN_FIRST=""
PANEL_ADMIN_LAST=""
PANEL_ADMIN_PASS=""

panel_status(){ [[ -f "$PANEL_DIR/artisan" ]] && echo '● DETECTED' || echo '○ NOT INSTALLED'; }

valid_domain(){
  [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}
valid_email(){ [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; }

prompt_nonempty(){
  local var="$1" label="$2" value=""
  while [[ -z "$value" ]]; do read -r -p "  $label › " value; [[ -n "$value" ]] || ui_warning "$label is required."; done
  printf -v "$var" '%s' "$value"
}

prompt_secret(){
  local var="$1" label="$2" value=""
  while [[ -z "$value" ]]; do read -r -s -p "  $label › " value; printf '\n'; [[ -n "$value" ]] || ui_warning "$label is required."; done
  printf -v "$var" '%s' "$value"
}

ensure_debian_php(){
  require_supported_os
  apt_install software-properties-common ca-certificates curl gnupg lsb-release
  if [[ "$OS_ID" == ubuntu ]]; then
    add-apt-repository -y ppa:ondrej/php
  elif [[ "$OS_ID" == debian ]]; then
    if ! apt-cache policy php8.3 >/dev/null 2>&1 || ! apt-cache show php8.3 >/dev/null 2>&1; then
      curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor --yes -o /usr/share/keyrings/sury-php.gpg
      echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(. /etc/os-release && echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/sury-php.list
    fi
  fi
  apt_install php8.3 php8.3-cli php8.3-common php8.3-gd php8.3-mysql php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip
}


install_composer(){
  if command -v composer >/dev/null 2>&1 && composer --version 2>/dev/null | grep -q 'Composer version 2'; then return; fi
  curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  chmod 0755 /usr/local/bin/composer
}

validate_node_inputs(){
  valid_uint "$NODE_RAM" && ((10#$NODE_RAM > 0)) || { ui_error 'Total Memory must be a positive integer in MB.'; return 1; }
  valid_percent "$NODE_RAM_OVER" || { ui_error 'Memory Overallocate must be 0-100%.'; return 1; }
  valid_uint "$NODE_DISK" && ((10#$NODE_DISK > 0)) || { ui_error 'Total Disk must be a positive integer in MB.'; return 1; }
  valid_percent "$NODE_DISK_OVER" || { ui_error 'Disk Overallocate must be 0-100%.'; return 1; }
  valid_port "$NODE_DAEMON_PORT" || { ui_error 'Invalid Daemon Port.'; return 1; }
  valid_port "$NODE_SFTP_PORT" || { ui_error 'Invalid SFTP Port.'; return 1; }
  valid_port "$NODE_ALLOC_START" && valid_port "$NODE_ALLOC_END" || { ui_error 'Invalid allocation range.'; return 1; }
  ((10#$NODE_ALLOC_START <= 10#$NODE_ALLOC_END)) || { ui_error 'Allocation start must be <= allocation end.'; return 1; }
  valid_ip_or_host "$NODE_ALLOC_IP" || { ui_error 'Invalid Allocation IP/host.'; return 1; }
  [[ "$NODE_SSL" == y || "$NODE_SSL" == n ]] || { ui_error 'SSL must be y or n.'; return 1; }
  [[ "$NODE_PROXY" == y || "$NODE_PROXY" == n ]] || { ui_error 'Behind Proxy must be y or n.'; return 1; }
}

validate_fqdn_dns(){
  if getent ahostsv4 "$NODE_FQDN" >/dev/null 2>&1; then
    ui_success "Node FQDN resolves: $NODE_FQDN"
    return 0
  fi
  ui_warning "Node FQDN does not currently resolve: $NODE_FQDN"
  read -r -p '  Continue anyway? [y/N] › ' ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

configure_database(){
  ui_section 'DATABASE'
  prompt_nonempty PANEL_DB_NAME 'Database Name'
  prompt_nonempty PANEL_DB_USER 'Database User'
  prompt_secret PANEL_DB_PASS 'Database Password'
  [[ "$PANEL_DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || { ui_error 'Database name may contain only letters, numbers, and underscore.'; return 1; }
  [[ "$PANEL_DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || { ui_error 'Database user may contain only letters, numbers, and underscore.'; return 1; }
  command -v mariadb >/dev/null 2>&1 || apt_install mariadb-server
  systemctl enable --now mariadb
  local passq
  passq="${PANEL_DB_PASS//\'/\'\'}"
  mariadb -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$PANEL_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$PANEL_DB_USER'@'127.0.0.1' IDENTIFIED BY '$passq';
ALTER USER '$PANEL_DB_USER'@'127.0.0.1' IDENTIFIED BY '$passq';
GRANT ALL PRIVILEGES ON \`$PANEL_DB_NAME\`.* TO '$PANEL_DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
  ui_success 'MariaDB database and user configured.'
}

configure_env(){
  local tz="${TZ:-Asia/Jakarta}" app_url="$PANEL_APP_URL"
  cd "$PANEL_DIR"
  cp -n .env.example .env
  php artisan key:generate --force
  php artisan p:environment:setup -n --author="$PANEL_ADMIN_EMAIL" --url="$app_url" --timezone="$tz" --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
  php artisan p:environment:database --host=127.0.0.1 --port=3306 --database="$PANEL_DB_NAME" --username="$PANEL_DB_USER" --password="$PANEL_DB_PASS"
  ui_success 'Panel environment configured.'
}

configure_nginx(){
  local ssl="$1" proxy="$2" conf="/etc/nginx/sites-available/pterodactyl.conf"
  rm -f /etc/nginx/sites-enabled/default
  if [[ "$ssl" == "y" ]]; then
    if [[ ! -s "/etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem" || ! -s "/etc/letsencrypt/live/$PANEL_DOMAIN/privkey.pem" ]]; then
      ui_warning 'SSL selected, but no certificate exists yet. Starting with HTTP so certbot can issue it.'
      ssl="n"
    fi
  fi
  cat >"$conf" <<NGINX
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    root $PANEL_DIR/public;
    index index.html index.htm index.php;
    charset utf-8;
    client_max_body_size 100m;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt { access_log off; log_not_found off; }
    access_log /var/log/nginx/pterodactyl.access.log;
    error_log /var/log/nginx/pterodactyl.error.log error;
    sendfile off;
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
NGINX
  ln -sf "$conf" /etc/nginx/sites-enabled/pterodactyl.conf
  nginx -t
  systemctl enable --now nginx php8.3-fpm
  systemctl reload nginx
  if [[ "$ssl" == "y" ]]; then
    cat >"$conf" <<NGINX
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $PANEL_DOMAIN;
    root $PANEL_DIR/public;
    index index.php;
    charset utf-8;
    client_max_body_size 100m;
    ssl_certificate /etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$PANEL_DOMAIN/privkey.pem;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    location ~ /\.ht { deny all; }
}
NGINX
    nginx -t && systemctl reload nginx
  fi
  ui_success "Nginx configured for $PANEL_DOMAIN."
  [[ "$proxy" == "y" ]] && ui_info 'Behind Proxy is enabled as a deployment choice; DNS/CDN proxy configuration remains external to the installer.'
}

issue_ssl(){
  ui_section 'SSL'
  apt_install certbot python3-certbot-nginx
  if certbot --nginx --non-interactive --agree-tos --redirect -m "$PANEL_ADMIN_EMAIL" -d "$PANEL_DOMAIN"; then
    PANEL_APP_URL="https://$PANEL_DOMAIN"
    ui_success "Let's Encrypt certificate issued for $PANEL_DOMAIN."
    return 0
  else
    PANEL_APP_URL="http://$PANEL_DOMAIN"
    ui_error 'Certbot failed. Panel remains on HTTP; check DNS and ports 80/443, then rerun SSL from your webserver setup.'
    return 1
  fi
}

configure_queue(){
  cat >/etc/systemd/system/pteroq.service <<UNIT
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service mariadb.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now pteroq
  (crontab -l 2>/dev/null | grep -vF "$PANEL_DIR/artisan schedule:run" || true; echo "* * * * * php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -
}

create_admin(){
  ui_section 'ADMIN ACCOUNT'
  prompt_nonempty PANEL_ADMIN_USER 'Admin Username'
  prompt_nonempty PANEL_ADMIN_FIRST 'Admin First Name'
  prompt_nonempty PANEL_ADMIN_LAST 'Admin Last Name'
  prompt_secret PANEL_ADMIN_PASS 'Admin Password'
  cd "$PANEL_DIR"
  php artisan p:user:make --email="$PANEL_ADMIN_EMAIL" --username="$PANEL_ADMIN_USER" --name-first="$PANEL_ADMIN_FIRST" --name-last="$PANEL_ADMIN_LAST" --password="$PANEL_ADMIN_PASS" --admin=1
}

install_panel(){
  require_root
  require_supported_os
  ui_section 'PTERODACTYL PANEL — INTERACTIVE SETUP'
  if [[ -f "$PANEL_DIR/artisan" ]]; then
    ui_warning 'Panel already exists. The installer will not overwrite it.'
    panel_maintenance
    return
  fi
  prompt_nonempty PANEL_DOMAIN 'Panel Domain'
  valid_domain "$PANEL_DOMAIN" || { ui_error 'Invalid domain format.'; return 1; }
  if getent ahostsv4 "$PANEL_DOMAIN" >/dev/null 2>&1; then
    ui_success "DNS resolves for $PANEL_DOMAIN."
  else
    ui_warning "DNS does not currently resolve for $PANEL_DOMAIN. Continuing only after your confirmation."
    read -r -p '  Continue anyway? [y/N] › ' ans
    [[ "$ans" =~ ^[Yy]$ ]] || return 1
  fi
  read -r -p '  Node Name › ' NODE_NAME
  [[ -n "$NODE_NAME" ]] || NODE_NAME="NODE-01"
  read -r -p '  Node Description [NODE BY ZXVCODE] › ' NODE_DESCRIPTION
  NODE_DESCRIPTION="${NODE_DESCRIPTION:-NODE BY ZXVCODE}"
  prompt_nonempty NODE_LOCATION 'Location Name'
  prompt_nonempty NODE_FQDN 'Node FQDN'
  valid_domain "$NODE_FQDN" || { ui_error 'Invalid Node FQDN.'; return 1; }
  validate_fqdn_dns || return 1
  read -r -p '  SSL [y/N] › ' NODE_SSL
  NODE_SSL="${NODE_SSL:-n}"; NODE_SSL="${NODE_SSL,,}"
  read -r -p '  Behind Proxy [y/N] › ' NODE_PROXY
  NODE_PROXY="${NODE_PROXY:-n}"; NODE_PROXY="${NODE_PROXY,,}"
  read -r -p '  Total Memory (MB) › ' NODE_RAM
  read -r -p '  Memory Overallocate (%) [0] › ' NODE_RAM_OVER
  NODE_RAM_OVER="${NODE_RAM_OVER:-0}"
  read -r -p '  Total Disk (MB) › ' NODE_DISK
  read -r -p '  Disk Overallocate (%) [0] › ' NODE_DISK_OVER
  NODE_DISK_OVER="${NODE_DISK_OVER:-0}"
  read -r -p '  Daemon Port [8080] › ' NODE_DAEMON_PORT
  NODE_DAEMON_PORT="${NODE_DAEMON_PORT:-8080}"
  read -r -p '  SFTP Port [2022] › ' NODE_SFTP_PORT
  NODE_SFTP_PORT="${NODE_SFTP_PORT:-2022}"
  read -r -p '  Allocation IP [0.0.0.0] › ' NODE_ALLOC_IP
  NODE_ALLOC_IP="${NODE_ALLOC_IP:-0.0.0.0}"
  read -r -p '  Allocation Start [2000] › ' NODE_ALLOC_START
  NODE_ALLOC_START="${NODE_ALLOC_START:-2000}"
  read -r -p '  Allocation End [2500] › ' NODE_ALLOC_END
  NODE_ALLOC_END="${NODE_ALLOC_END:-2500}"
  prompt_nonempty PANEL_ADMIN_EMAIL 'Admin Email'
  valid_email "$PANEL_ADMIN_EMAIL" || { ui_error 'Invalid email.'; return 1; }

  validate_node_inputs || return 1
  PANEL_APP_URL="http://$PANEL_DOMAIN"
  ui_section 'REVIEW'
  printf '  Panel Domain       : %s\n  Database            : interactive\n  Node Name           : %s\n  Node Description    : %s\n  Location            : %s\n  Node FQDN           : %s\n  SSL / Proxy         : %s / %s\n  RAM / Overallocate  : %s MB / %s%%\n  Disk / Overallocate : %s MB / %s%%\n  Daemon / SFTP       : %s / %s\n  Allocation          : %s:%s-%s\n' "$PANEL_DOMAIN" "$NODE_NAME" "$NODE_DESCRIPTION" "$NODE_LOCATION" "$NODE_FQDN" "$NODE_SSL" "$NODE_PROXY" "$NODE_RAM" "$NODE_RAM_OVER" "$NODE_DISK" "$NODE_DISK_OVER" "$NODE_DAEMON_PORT" "$NODE_SFTP_PORT" "$NODE_ALLOC_IP" "$NODE_ALLOC_START" "$NODE_ALLOC_END"
  read -r -p '  Continue setup? [Y/n] › ' confirm
  [[ ! "$confirm" =~ ^[Nn]$ ]] || return 0

  apt_install curl ca-certificates git unzip tar nginx mariadb-server redis-server
  ensure_debian_php
  install_composer
  systemctl enable --now redis-server mariadb php8.3-fpm

  configure_database
  mkdir -p "$PANEL_DIR"
  cd "$PANEL_DIR"
  curl -fL -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
  tar -xzf panel.tar.gz
  rm -f panel.tar.gz
  chmod -R 755 storage bootstrap/cache
  install_composer
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction
  create_admin_precheck=1
  configure_env
  php artisan migrate --seed --force
  create_admin
  chown -R www-data:www-data "$PANEL_DIR"
  mkdir -p /etc/pterodactyl
  cat >/etc/pterodactyl/zxvcode-node-profile.conf <<EOF
NODE_NAME=$(printf '%q' "$NODE_NAME")
NODE_DESCRIPTION=$(printf '%q' "$NODE_DESCRIPTION")
NODE_LOCATION=$(printf '%q' "$NODE_LOCATION")
NODE_FQDN=$(printf '%q' "$NODE_FQDN")
NODE_SSL=$(printf '%q' "$NODE_SSL")
NODE_PROXY=$(printf '%q' "$NODE_PROXY")
NODE_RAM=$(printf '%q' "$NODE_RAM")
NODE_RAM_OVER=$(printf '%q' "$NODE_RAM_OVER")
NODE_DISK=$(printf '%q' "$NODE_DISK")
NODE_DISK_OVER=$(printf '%q' "$NODE_DISK_OVER")
NODE_DAEMON_PORT=$(printf '%q' "$NODE_DAEMON_PORT")
NODE_SFTP_PORT=$(printf '%q' "$NODE_SFTP_PORT")
NODE_ALLOC_IP=$(printf '%q' "$NODE_ALLOC_IP")
NODE_ALLOC_START=$(printf '%q' "$NODE_ALLOC_START")
NODE_ALLOC_END=$(printf '%q' "$NODE_ALLOC_END")
EOF
  chmod 0600 /etc/pterodactyl/zxvcode-node-profile.conf
  configure_queue
  configure_nginx "n" "$NODE_PROXY"
  if [[ "$NODE_SSL" == "y" ]]; then
    issue_ssl || true
  fi
  if [[ "$PANEL_APP_URL" == https://* ]]; then
    php artisan p:environment:setup -n --author="$PANEL_ADMIN_EMAIL" --url="$PANEL_APP_URL" --timezone="${TZ:-Asia/Jakarta}" --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
  fi
  php artisan optimize:clear
  nginx -t
  ui_success 'Panel installation completed.'
  ui_info 'The Node itself is created in Panel > Nodes. Wings must use the config.yml generated by that Node.'
  ui_info "Node summary: $NODE_NAME / $NODE_LOCATION / $NODE_FQDN / daemon $NODE_DAEMON_PORT / SFTP $NODE_SFTP_PORT"
}
panel_maintenance(){
  require_root
  [[ -f "$PANEL_DIR/artisan" ]] || { ui_error 'Panel not found.'; return; }
  cd "$PANEL_DIR"
  php artisan optimize:clear
  php artisan migrate --force
  chown -R www-data:www-data storage bootstrap/cache
  systemctl restart pteroq 2>/dev/null || true
  ui_success 'Maintenance completed.'
}
