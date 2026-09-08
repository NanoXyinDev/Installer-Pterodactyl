#!/usr/bin/env bash
set -euo pipefail
umask 022

REPO_ARCHIVE_URL="https://github.com/NanoXyinDev/Installer-Pterodactyl-v1/archive/refs/heads/main.tar.gz"
SOURCE_PATH="${BASH_SOURCE[0]-}"
BASE_DIR=""

if [[ -n "$SOURCE_PATH" ]]; then
  CANDIDATE_DIR="$(cd "$(dirname "$SOURCE_PATH")" 2>/dev/null && pwd -P)" || CANDIDATE_DIR=""
  if [[ -f "$CANDIDATE_DIR/config/defaults.conf" ]]; then
    BASE_DIR="$CANDIDATE_DIR"
  fi
fi

if [[ -z "$BASE_DIR" ]]; then
  command -v curl >/dev/null 2>&1 || { printf 'curl is required to bootstrap the installer.\n' >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { printf 'tar is required to bootstrap the installer.\n' >&2; exit 1; }
  BOOTSTRAP_DIR="$(mktemp -d /tmp/zxvcode-ptero.XXXXXX)"
  cleanup_bootstrap() { rm -rf "$BOOTSTRAP_DIR"; }
  trap cleanup_bootstrap EXIT INT TERM
  ARCHIVE="$BOOTSTRAP_DIR/project.tar.gz"
  curl -fsSL --retry 3 --retry-delay 1 "$REPO_ARCHIVE_URL" -o "$ARCHIVE"
  tar -tzf "$ARCHIVE" >/dev/null
  tar -xzf "$ARCHIVE" -C "$BOOTSTRAP_DIR"
  BASE_DIR="$(find "$BOOTSTRAP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'Installer-Pterodactyl-v1-*' -print -quit)"
  [[ -n "$BASE_DIR" && -f "$BASE_DIR/config/defaults.conf" ]] || { printf 'Downloaded installer is incomplete.\n' >&2; exit 1; }
  bash "$BASE_DIR/install.sh" "$@"
  exit $?
fi

DEFAULTS_FILE="$BASE_DIR/config/defaults.conf"
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
  printf '\n  [01] Install or configure Panel + initial Node\n  [02] Install or repair Wings\n  [03] Configure Node and Location\n  [04] Manage allocations\n  [05] Panel appearance\n  [06] Protection\n  [07] Disk safeguards\n  [08] Panel maintenance\n  [09] System health check\n  [10] Backup and recovery\n  [11] Remove Panel\n  [00] Exit\n\n'
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
