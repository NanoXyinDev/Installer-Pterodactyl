#!/usr/bin/env bash
set -euo pipefail

DISK_GUARD_SERVICE=/etc/systemd/system/zxvcode-disk-guard.service
DISK_GUARD_SCRIPT=/usr/local/sbin/zxvcode-disk-guard
DISK_GUARD_LOG=/var/log/zxvcode-disk-guard.log
DISK_GUARD_THRESHOLD=100
DISK_GUARD_INTERVAL=60

volume_path(){
  for p in /var/lib/pterodactyl/volumes /var/pterodactyl/volume; do
    [[ -d "$p" ]] && { printf '%s\n' "$p"; return; }
  done
  printf '%s\n' /var/lib/pterodactyl/volumes
}

disk_usage_percent(){
  local path="$1"
  df -P -x tmpfs -x devtmpfs -- "$path" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

largest_server_volume(){
  local base="$1"
  find "$base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null |
    xargs -0 -r du -x -s -B1 2>/dev/null |
    sort -n | tail -1 | cut -f2-
}

valid_server_uuid(){
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]
}

server_exists_in_panel(){
  local uuid="$1" panel="${PANEL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -f "$panel/.env" && -f "$panel/artisan" && -f "$panel/vendor/autoload.php" ]] || return 1
  command -v php >/dev/null 2>&1 || return 1
  php -r 'require $argv[1]."/vendor/autoload.php"; $app=require $argv[1]."/bootstrap/app.php"; $app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); $server=Pterodactyl\\Models\\Server::where("uuid",$argv[2])->first(); exit($server?0:1);' "$panel" "$uuid" >/dev/null 2>&1
}

panel_delete_server(){
  local uuid="$1" panel="${PANEL_DIRECTORY:-/var/www/pterodactyl}"
  php -r 'require $argv[1]."/vendor/autoload.php"; $app=require $argv[1]."/bootstrap/app.php"; $app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); $server=Pterodactyl\\Models\\Server::where("uuid",$argv[2])->firstOrFail(); app(Pterodactyl\\Services\\Servers\\ServerDeletionService::class)->withForce()->handle($server);' "$panel" "$uuid"
}

delete_largest_server(){
  local base usage volume uuid
  base="$(volume_path)"
  usage="$(disk_usage_percent "$base" || true)"
  [[ "$usage" =~ ^[0-9]+$ ]] || return 0
  (( usage >= DISK_GUARD_THRESHOLD )) || return 0

  volume="$(largest_server_volume "$base" || true)"
  [[ -n "$volume" && -d "$volume" ]] || return 0
  uuid="$(basename "$volume")"
  valid_server_uuid "$uuid" || { printf '%s REFUSE invalid volume name: %s\n' "$(date -Is)" "$uuid" >> "$DISK_GUARD_LOG"; return 0; }

  if ! server_exists_in_panel "$uuid"; then
    printf '%s REFUSE unmapped volume: %s usage=%s%%\n' "$(date -Is)" "$uuid" "$usage" >> "$DISK_GUARD_LOG"
    return 0
  fi

  printf '%s FULL DISK usage=%s%% largest=%s action=panel-force-delete\n' "$(date -Is)" "$usage" "$uuid" >> "$DISK_GUARD_LOG"
  if panel_delete_server "$uuid" >> "$DISK_GUARD_LOG" 2>&1; then
    printf '%s DELETE OK %s\n' "$(date -Is)" "$uuid" >> "$DISK_GUARD_LOG"
    sleep 300
    return 0
  fi
  printf '%s DELETE FAILED %s; volume left intact\n' "$(date -Is)" "$uuid" >> "$DISK_GUARD_LOG"
}

disk_guard_loop(){
  mkdir -p "$(dirname "$DISK_GUARD_LOG")"
  touch "$DISK_GUARD_LOG"
  chmod 600 "$DISK_GUARD_LOG"
  while :; do
    delete_largest_server || true
    sleep "$DISK_GUARD_INTERVAL"
  done
}

disk_guard_menu(){
  while true; do
    ui_section 'DISK PROTECTION'
    printf '  Threshold        100%% filesystem usage\n  Interval         60 seconds\n  [01] Scan volumes\n  [02] Install full disk guard\n  [03] Guard status\n  [04] View guard log\n  [00] Back\n\n'
    read -r -p '  Select › ' d
    case "$d" in
      1) scan_volumes ;;
      2) install_disk_guard ;;
      3) systemctl --no-pager --full status zxvcode-disk-guard.service || true ;;
      4) tail -n 80 "$DISK_GUARD_LOG" 2>/dev/null || ui_warning 'No guard log yet.' ;;
      0|00) return ;;
      *) ui_warning 'Unknown option.' ;;
    esac
  done
}

scan_volumes(){
  local base
  base="$(volume_path)"
  [[ -d "$base" ]] || { ui_error "Volume path not found: $base"; return; }
  printf '\n  Filesystem usage: %s%%\n\n' "$(disk_usage_percent "$base" || printf '?')"
  find "$base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null |
    xargs -0 -r du -x -h -s 2>/dev/null | sort -h |
    tail -n 30
}

install_disk_guard(){
  mkdir -p "$(dirname "$DISK_GUARD_SCRIPT")" "$(dirname "$DISK_GUARD_LOG")"
  cat > "$DISK_GUARD_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
PANEL_DIRECTORY='${PANEL_DIRECTORY:-/var/www/pterodactyl}'
DISK_GUARD_THRESHOLD=100
DISK_GUARD_INTERVAL=60
DISK_GUARD_LOG='${DISK_GUARD_LOG}'
volume_path(){ for p in /var/lib/pterodactyl/volumes /var/pterodactyl/volume; do [[ -d "\$p" ]] && { printf '%s\\n' "\$p"; return; }; done; printf '%s\\n' /var/lib/pterodactyl/volumes; }
disk_usage_percent(){ df -P -x tmpfs -x devtmpfs -- "\$1" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",\$5); print \$5}'; }
largest_server_volume(){ find "\$1" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | xargs -0 -r du -x -s -B1 2>/dev/null | sort -n | tail -1 | cut -f2-; }
valid_server_uuid(){ [[ "\$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\$ ]]; }
server_exists_in_panel(){ local uuid="\$1" panel="\$PANEL_DIRECTORY"; [[ -f "\$panel/.env" && -f "\$panel/artisan" && -f "\$panel/vendor/autoload.php" ]] || return 1; command -v php >/dev/null 2>&1 || return 1; php -r 'require \$argv[1]."/vendor/autoload.php"; \$app=require \$argv[1]."/bootstrap/app.php"; \$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); \$server=Pterodactyl\\Models\\Server::where("uuid",\$argv[2])->first(); exit(\$server?0:1);' "\$panel" "\$uuid" >/dev/null 2>&1; }
panel_delete_server(){ local uuid="\$1" panel="\$PANEL_DIRECTORY"; php -r 'require \$argv[1]."/vendor/autoload.php"; \$app=require \$argv[1]."/bootstrap/app.php"; \$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); \$server=Pterodactyl\\Models\\Server::where("uuid",\$argv[2])->firstOrFail(); app(Pterodactyl\\Services\\Servers\\ServerDeletionService::class)->withForce()->handle(\$server);' "\$panel" "\$uuid"; }
delete_largest_server(){ local base usage volume uuid; base="\$(volume_path)"; usage="\$(disk_usage_percent "\$base" || true)"; [[ "\$usage" =~ ^[0-9]+\$ ]] || return 0; (( usage >= DISK_GUARD_THRESHOLD )) || return 0; volume="\$(largest_server_volume "\$base" || true)"; [[ -n "\$volume" && -d "\$volume" ]] || return 0; uuid="\$(basename "\$volume")"; valid_server_uuid "\$uuid" || { printf '%s REFUSE invalid volume name: %s\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"; return 0; }; server_exists_in_panel "\$uuid" || { printf '%s REFUSE unmapped volume: %s usage=%s%%\\n' "\$(date -Is)" "\$uuid" "\$usage" >> "\$DISK_GUARD_LOG"; return 0; }; printf '%s FULL DISK usage=%s%% largest=%s action=panel-force-delete\\n' "\$(date -Is)" "\$usage" "\$uuid" >> "\$DISK_GUARD_LOG"; if panel_delete_server "\$uuid" >> "\$DISK_GUARD_LOG" 2>&1; then printf '%s DELETE OK %s\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"; sleep 300; else printf '%s DELETE FAILED %s; volume left intact\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"; fi; }
mkdir -p "\$(dirname "\$DISK_GUARD_LOG")"; touch "\$DISK_GUARD_LOG"; chmod 600 "\$DISK_GUARD_LOG"; while :; do delete_largest_server || true; sleep "\$DISK_GUARD_INTERVAL"; done
SCRIPT
  chmod 700 "$DISK_GUARD_SCRIPT"
  cat > "$DISK_GUARD_SERVICE" <<SERVICE
[Unit]
Description=ZXVCode Pterodactyl full disk protection
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=$DISK_GUARD_SCRIPT
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ReadWritePaths=/var/lib/pterodactyl/volumes /var/pterodactyl/volume /var/log

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
  systemctl enable --now zxvcode-disk-guard.service
  ui_success 'Full disk guard installed and running continuously.'
  ui_warning 'At 100% filesystem usage it selects the largest valid UUID-mapped Pterodactyl volume and deletes that server through Pterodactyl ServerDeletionService. Unmapped volumes are never deleted.'
}

