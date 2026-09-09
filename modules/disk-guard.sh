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
    local status='OFF'
    systemctl is-active --quiet zxvcode-disk-guard.service 2>/dev/null && status='RUNNING'
    printf '  Status           : %s\n  Threshold        : 100%% filesystem usage\n  Interval         : 60 seconds\n  Volume root      : %s\n\n' "$status" "$(volume_path)"
    printf '  [ + ] 1. Scan volumes\n  [ + ] 2. Install full disk guard\n  [ + ] 3. Guard status\n  [ + ] 4. View guard log\n  [ + ] 0. Back\n\n'
    read -r -p '  Select › ' d
    case "$d" in
      1|01) scan_volumes ;;
      2|02) install_disk_guard ;;
      3|03)
        ui_section 'GUARD STATUS'
        if systemctl is-active --quiet zxvcode-disk-guard.service 2>/dev/null; then
          ui_success 'Disk guard is running.'
          systemctl --no-pager --full status zxvcode-disk-guard.service | sed -n '1,18p'
        else
          ui_warning 'Disk guard is not running.'
          systemctl --no-pager --full status zxvcode-disk-guard.service | sed -n '1,18p' || true
        fi
        ;;
      4|04)
        ui_section 'GUARD LOG'
        if [[ -s "$DISK_GUARD_LOG" ]]; then
          tail -n 80 "$DISK_GUARD_LOG"
        else
          ui_warning 'Belum ada log. Guard belum menemukan event.'
        fi
        ;;
      0|00) return ;;
      *) ui_warning 'Pilihan itu belum ada. Pilih nomor yang terlihat di atas.' ;;
    esac
  done
}

scan_volumes(){
  local base usage count=0 total=0
  base="$(volume_path)"
  [[ -d "$base" ]] || { ui_error "Volume path not found: $base"; return; }
  usage="$(disk_usage_percent "$base" || printf '?')"
  total="$(find "$base" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | wc -l | tr -d ' ')"

  ui_section 'SCAN VOLUMES'
  printf '  Root             : %s\n  Filesystem usage  : %s%%\n  Server volumes    : %s\n\n' "$base" "$usage" "$total"
  if (( total == 0 )); then
    ui_warning 'Belum ada folder volume server.'
    return
  fi

  printf '  Scanning volume size...\n'
  local line path size uuid mapped
  while IFS=$'\t' read -r size path; do
    [[ -n "$path" ]] || continue
    uuid="$(basename "$path")"
    if valid_server_uuid "$uuid" && server_exists_in_panel "$uuid"; then
      mapped='MAPPED'
    else
      mapped='UNMAPPED'
    fi
    count=$((count+1))
    ui_progress_steps "$count" "$total" "Check $uuid"
    printf '\n    %-36s %-10s %s\n' "$uuid" "$size" "$mapped"
  done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | xargs -0 -r du -x -h -s 2>/dev/null | sort -h | awk -F'\t' 'NF>=2 {print $1 "\t" $2}')
  printf '\n'
  ui_success "Scan selesai: $count/$total volume diperiksa."
  if [[ "$usage" =~ ^[0-9]+$ ]] && (( usage >= DISK_GUARD_THRESHOLD )); then
    ui_warning 'Filesystem sudah 100%. Guard akan mencari volume UUID yang valid dan terdaftar di Panel.'
  else
    ui_info 'Filesystem belum mencapai threshold 100%. Tidak ada server yang disentuh.'
  fi
}

install_disk_guard(){
  require_root
  local base
  base="$(volume_path)"
  ui_section 'INSTALL FULL DISK GUARD'
  ui_step '[01/06] Cek kebutuhan sistem'
  command -v systemctl >/dev/null 2>&1 || { ui_error 'systemd/systemctl tidak tersedia.'; return 1; }
  command -v php >/dev/null 2>&1 || ui_warning 'PHP belum terdeteksi. Guard baru akan bisa menghapus server setelah Panel/PHP tersedia.'
  [[ -d "$base" ]] || ui_warning "Volume root belum ada: $base"
  ui_step_ok 'System check selesai.'

  ui_step '[02/06] Tulis guard worker'
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
delete_largest_server(){
  local base usage volume uuid
  base="\$(volume_path)"
  usage="\$(disk_usage_percent "\$base" || true)"
  [[ "\$usage" =~ ^[0-9]+\$ ]] || return 0
  (( usage >= DISK_GUARD_THRESHOLD )) || return 0
  volume="\$(largest_server_volume "\$base" || true)"
  [[ -n "\$volume" && -d "\$volume" ]] || return 0
  uuid="\$(basename "\$volume")"
  valid_server_uuid "\$uuid" || { printf '%s REFUSE invalid volume name: %s\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"; return 0; }
  if ! server_exists_in_panel "\$uuid"; then
    printf '%s REFUSE unmapped volume: %s usage=%s%%\\n' "\$(date -Is)" "\$uuid" "\$usage" >> "\$DISK_GUARD_LOG"
    return 0
  fi
  printf '%s FULL DISK usage=%s%% largest=%s action=panel-force-delete\\n' "\$(date -Is)" "\$usage" "\$uuid" >> "\$DISK_GUARD_LOG"
  if panel_delete_server "\$uuid" >> "\$DISK_GUARD_LOG" 2>&1; then
    printf '%s DELETE OK %s\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"
    sleep 300
  else
    printf '%s DELETE FAILED %s; volume left intact\\n' "\$(date -Is)" "\$uuid" >> "\$DISK_GUARD_LOG"
  fi
}
mkdir -p "\$(dirname "\$DISK_GUARD_LOG")"
touch "\$DISK_GUARD_LOG"
chmod 600 "\$DISK_GUARD_LOG"
while :; do
  delete_largest_server || true
  sleep "\$DISK_GUARD_INTERVAL"
done
SCRIPT
  chmod 700 "$DISK_GUARD_SCRIPT"
  bash -n "$DISK_GUARD_SCRIPT"
  ui_step_ok 'Guard worker valid dan executable.'

  ui_step '[03/06] Tulis service systemd'
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
# Namespace sandboxing is intentionally disabled for this worker.
# The guard must access the real Pterodactyl volume filesystem, and
# incompatible namespace rules can make systemd exit with 226/NAMESPACE.

[Install]
WantedBy=multi-user.target
SERVICE
  chmod 644 "$DISK_GUARD_SERVICE"
  ui_step_ok 'Service systemd siap.'

  ui_step '[04/06] Aktifkan guard'
  systemctl daemon-reload
  systemctl enable zxvcode-disk-guard.service >/dev/null
  systemctl restart zxvcode-disk-guard.service
  ui_step_ok 'Service di-enable dan dijalankan.'

  ui_step '[05/06] Cek health guard'
  sleep 1
  if systemctl is-active --quiet zxvcode-disk-guard.service; then
    ui_step_ok 'Guard aktif dan berjalan terus.'
  else
    ui_step_fail 'Guard gagal aktif.'
    systemctl --no-pager --full status zxvcode-disk-guard.service | sed -n '1,22p' || true
    return 1
  fi

  ui_step '[06/06] Simpan log & status'
  touch "$DISK_GUARD_LOG"
  chmod 600 "$DISK_GUARD_LOG"
  printf '%s INSTALLED threshold=%s%% interval=%ss root=%s\n' "$(date -Is)" "$DISK_GUARD_THRESHOLD" "$DISK_GUARD_INTERVAL" "$base" >> "$DISK_GUARD_LOG"
  ui_step_ok "Log: $DISK_GUARD_LOG"

  ui_section 'DISK GUARD READY'
  ui_success 'Full disk guard installed and running continuously.'
  ui_info 'Threshold 100% • scan interval 60 seconds.'
  ui_info 'Hanya folder volume dengan UUID valid yang terdaftar sebagai Server di Panel yang dipertimbangkan.'
  ui_info 'Volume yang tidak terpetakan akan dilewati.'
}
