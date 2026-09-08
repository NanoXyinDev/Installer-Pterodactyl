#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_FILE="$BASE_DIR/config/defaults.conf"
[[ -f "$DEFAULTS_FILE" ]] || { printf "Missing defaults: %s\n" "$DEFAULTS_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$DEFAULTS_FILE"
PTERODACTYL_DIRECTORY="${PANEL_DIRECTORY:-/var/www/pterodactyl}"
export PTERODACTYL_DIRECTORY
for f in lib/ui.sh lib/detect.sh lib/system.sh lib/panel.sh modules/wings.sh modules/node.sh modules/allocation.sh modules/theme.sh modules/protection.sh modules/disk-guard.sh modules/doctor.sh modules/backup.sh; do
  [[ -f "$BASE_DIR/$f" ]] || { printf 'Missing installer file: %s\n' "$BASE_DIR/$f" >&2; exit 1; }
  source "$BASE_DIR/$f"
done
require_root
clear 2>/dev/null || true
ui_header
printf '\n  Access key required.\n\n'
read -r -s -p '  Key › ' entered
printf '\n'
[[ "$entered" == "$ACCESS_KEY" ]] || { ui_error 'Invalid access key.'; exit 1; }
ui_success 'Access granted.'
detect_system
require_supported_os
while true; do
  ui_dashboard
  printf '\n  [01] Install or configure Panel and Node\n  [02] Install or repair Wings\n  [03] Configure Node and Location\n  [04] Manage allocations\n  [05] Panel appearance\n  [06] Protection\n  [07] Disk safeguards\n  [08] Panel maintenance\n  [09] System health check\n  [10] Backup and recovery\n  [11] Remove Panel\n  [00] Exit\n\n'
  read -r -p '  Select option › ' opt
  case "$opt" in
    1) install_panel;;
    2) install_wings;;
    3) node_menu;;
    4) allocation_menu;;
    5) theme_menu;;
    6) protection_menu;;
    7) disk_guard_menu;;
    8) panel_maintenance;;
    9) doctor_menu;;
    10|10) backup_menu;;
    11) "$BASE_DIR/uninstallpanel.sh";;
    0|00) exit 0;;
    *) ui_warning 'Unknown option.';;
  esac
  printf '\n  Press Enter to continue...'
  read -r
done
