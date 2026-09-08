#!/usr/bin/env bash
set -euo pipefail

backup_root="/var/backups/zxvcode-ptero"

create_panel_backup() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}" stamp out dbname dbuser
  [[ -f "$panel/.env" ]] || { ui_error 'Panel .env was not found.'; return 1; }
  stamp="$(date +%Y%m%d-%H%M%S)"
  out="$backup_root/panel-$stamp"
  mkdir -p "$out"
  cp -a "$panel/.env" "$out/.env"
  [[ -f /etc/pterodactyl/config.yml ]] && cp -a /etc/pterodactyl/config.yml "$out/config.yml"
  [[ -f /etc/pterodactyl/zxvcode-node-profile.conf ]] && cp -a /etc/pterodactyl/zxvcode-node-profile.conf "$out/node-profile.conf"
  dbname="$(php -r '$e=parse_ini_file("'"$panel"'"/.env"); echo $e["DB_DATABASE"] ?? "";' 2>/dev/null || true)"
  dbuser="$(php -r '$e=parse_ini_file("'"$panel"'"/.env"); echo $e["DB_USERNAME"] ?? "";' 2>/dev/null || true)"
  if [[ -n "$dbname" && -n "$dbuser" ]] && command -v mariadb-dump >/dev/null 2>&1; then
    mariadb-dump --single-transaction --quick --routines --triggers "$dbname" > "$out/database.sql" || rm -f "$out/database.sql"
  fi
  tar -C "$out" -czf "$out.tar.gz" .
  rm -rf "$out"
  chmod 0600 "$out.tar.gz"
  ui_success "Backup created: $out.tar.gz"
}

list_backups() {
  mkdir -p "$backup_root"
  find "$backup_root" -maxdepth 1 -type f -name '*.tar.gz' -printf '  %TY-%Tm-%Td %TH:%TM  %s bytes  %f\n' | sort -r || true
}

backup_menu() {
  while true; do
    ui_section 'BACKUP & RECOVERY'
    printf '  [01] Create Panel backup\n  [02] Backup current theme files\n  [03] List backups\n  [04] Verify backup archive\n  [00] Back\n\n'
    read -r -p '  Select › ' choice
    case "$choice" in
      1|01) create_panel_backup;;
      2|02) backup_theme_files;;
      3|03) list_backups;;
      4|04)
        local file
        read -r -p '  Backup file › ' file
        [[ -f "$file" ]] && tar -tzf "$file" >/dev/null && ui_success 'Backup archive is readable.' || ui_error 'Backup archive could not be verified.';;
      0|00) return;;
      *) ui_warning 'Unknown option.';;
    esac
  done
}
