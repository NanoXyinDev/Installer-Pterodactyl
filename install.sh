#!/usr/bin/env bash
set -euo pipefail
umask 022

REPO_ARCHIVE_URL="https://github.com/NanoXyinDev/Installer-Pterodactyl-v1/archive/refs/heads/main.tar.gz"

disk_available_kb() {
  df -Pk "$1" 2>/dev/null | awk 'NR==2 {print $4}'
}

try_emergency_cleanup() {
  local before after
  before="$(disk_available_kb / 2>/dev/null || printf '0')"
  printf '\n  Storage VPS lagi penuh, jadi installer belum bisa mulai.\n' >&2
  printf '  Gue coba beresin cache dan file sementara yang aman dulu...\n\n' >&2
  find /tmp -mindepth 1 -maxdepth 1 -type f -mtime +1 -delete 2>/dev/null || true
  find /var/tmp -mindepth 1 -maxdepth 1 -type f -mtime +1 -delete 2>/dev/null || true
  if command -v apt-get >/dev/null 2>&1; then
    apt-get clean >/dev/null 2>&1 || true
  fi
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --vacuum-size=100M >/dev/null 2>&1 || true
  fi
  after="$(disk_available_kb / 2>/dev/null || printf '0')"
  if [[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ && "$after" -gt "$before" ]]; then
    printf '  Oke, sekarang ada sekitar %s MB ruang kosong.\n' "$((after / 1024))" >&2
  else
    printf '  Belum cukup lega. Gue tidak akan menghapus volume/data server secara otomatis.\n' >&2
  fi
}

choose_tmp_root() {
  local candidate available
  for candidate in "${TMPDIR:-/tmp}" /var/tmp /dev/shm /root/.cache; do
    [[ -d "$candidate" && -w "$candidate" ]] || continue
    available="$(disk_available_kb "$candidate")"
    if [[ "$available" =~ ^[0-9]+$ ]] && (( available >= 8192 )); then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  try_emergency_cleanup
  for candidate in "${TMPDIR:-/tmp}" /var/tmp /dev/shm /root/.cache; do
    [[ -d "$candidate" && -w "$candidate" ]] || continue
    available="$(disk_available_kb "$candidate")"
    if [[ "$available" =~ ^[0-9]+$ ]] && (( available >= 8192 )); then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '\n  Disk VPS masih penuh. Minimal butuh sekitar 8 MB ruang kosong untuk mulai.\n' >&2
  printf '  Cek dengan: df -h && df -i\n' >&2
  printf '  Cari pemakan storage: du -xhd1 / 2>/dev/null | sort -h\n' >&2
  return 1
}

create_tmpdir() {
  local root="$1"
  mktemp -d "$root/zxvcode-ptero.XXXXXX" 2>/dev/null || {
    printf '\n  Gue gagal bikin folder kerja di %s. Disk kemungkinan masih penuh.\n' "$root" >&2
    return 1
  }
}
SOURCE_PATH="${BASH_SOURCE[0]-}"
BASE_DIR=""

if [[ -n "$SOURCE_PATH" ]]; then
  CANDIDATE_DIR="$(cd "$(dirname "$SOURCE_PATH")" 2>/dev/null && pwd -P)" || CANDIDATE_DIR=""
  if [[ -f "$CANDIDATE_DIR/config/defaults.conf" ]]; then
    BASE_DIR="$CANDIDATE_DIR"
  fi
fi

if [[ -z "$BASE_DIR" ]]; then
  command -v curl >/dev/null 2>&1 || { printf 'curl dibutuhkan untuk memulai installer.\n' >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { printf 'tar dibutuhkan untuk memulai installer.\n' >&2; exit 1; }
  TMP_ROOT="$(choose_tmp_root)"
  BOOTSTRAP_DIR="$(create_tmpdir "$TMP_ROOT")"
  cleanup_bootstrap() { rm -rf "$BOOTSTRAP_DIR"; }
  trap cleanup_bootstrap EXIT INT TERM
  ARCHIVE="$BOOTSTRAP_DIR/project.tar.gz"
  curl -fsSL --retry 3 --retry-delay 1 "$REPO_ARCHIVE_URL" -o "$ARCHIVE"
  tar -tzf "$ARCHIVE" >/dev/null
  tar -xzf "$ARCHIVE" -C "$BOOTSTRAP_DIR"
  BASE_DIR="$(find "$BOOTSTRAP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'Installer-Pterodactyl-v1-*' -print -quit)"
  [[ -n "$BASE_DIR" && -f "$BASE_DIR/config/defaults.conf" ]] || { printf 'File installer yang diunduh belum lengkap.\n' >&2; exit 1; }
  bash "$BASE_DIR/install.sh" "$@"
  exit $?
fi

DEFAULTS_FILE="$BASE_DIR/config/defaults.conf"
# shellcheck disable=SC1090
source "$DEFAULTS_FILE"
PTERODACTYL_DIRECTORY="${PANEL_DIRECTORY:-/var/www/pterodactyl}"
export PTERODACTYL_DIRECTORY
for f in lib/ui.sh lib/detect.sh lib/system.sh lib/panel.sh modules/wings.sh modules/node.sh modules/allocation.sh modules/theme.sh modules/protection.sh modules/antiflood.sh modules/roles.sh modules/disk-guard.sh modules/doctor.sh modules/backup.sh; do
  [[ -f "$BASE_DIR/$f" ]] || { printf 'File installer tidak ditemukan: %s\n' "$BASE_DIR/$f" >&2; exit 1; }
  source "$BASE_DIR/$f"
done
require_root
clear 2>/dev/null || true
ui_header
printf '\n  Masukkan access key dulu ya.\n\n'
read -r -s -p '  Key › ' entered
printf '\n'
[[ "$entered" == "$ACCESS_KEY" ]] || { ui_error 'Invalid access key.'; exit 1; }
ui_success 'Access granted.'
detect_system
require_supported_os
while true; do
  ui_dashboard
  printf '\n  [ + ] 1. Pasang Panel\n  [ + ] 2. Pasang Wings & perbaiki\n  [ + ] 3. Node & lokasi\n  [ + ] 4. Atur allocation\n  [ + ] 5. Atur tampilan Panel\n  [ + ] 6. Perlindungan Panel\n  [ + ] 7. Anti FLOOD / penjaga DDoS\n  [ + ] 8. Role & dashboard admin\n  [ + ] 9. Penjaga disk\n  [ + ] 10. Maintenance\n  [ + ] 11. Cek kondisi sistem\n  [ + ] 12. Backup & pemulihan\n  [ + ] 13. Hapus Panel\n  [ + ] 0. Keluar\n\n'
  read -r -p '  Pilih yang mau dilakukan › ' opt
  case "$opt" in
    1) install_panel;;
    2) install_wings;;
    3) node_menu;;
    4) allocation_menu;;
    5) theme_menu;;
    6) protection_menu;;
    7) antiflood_menu;;
    8) roles_menu;;
    9) disk_guard_menu;;
    10) panel_maintenance;;
    11) doctor_menu;;
    12) backup_menu;;
    13) "$BASE_DIR/uninstallpanel.sh";;
    0|00) ui_farewell; exit 0;;
    *) ui_warning 'Nomor itu belum ada.';;
  esac
  printf '\n  Tekan Enter kalau mau lanjut...'
  read -r
done
