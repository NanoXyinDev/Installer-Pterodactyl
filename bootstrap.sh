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
command -v curl >/dev/null 2>&1 || { printf 'curl is required.\n' >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { printf 'tar is required.\n' >&2; exit 1; }
TMP_ROOT="$(choose_tmp_root)"
TMP_DIR="$(create_tmpdir "$TMP_ROOT")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM
ARCHIVE="$TMP_DIR/project.tar.gz"
curl -fsSL --retry 3 --retry-delay 1 "$REPO_ARCHIVE_URL" -o "$ARCHIVE"
tar -tzf "$ARCHIVE" >/dev/null
tar -xzf "$ARCHIVE" -C "$TMP_DIR"
ROOT_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'Installer-Pterodactyl-v1-*' -print -quit)"
[[ -n "$ROOT_DIR" ]] || { printf 'Installer archive root not found.\n' >&2; exit 1; }
[[ -f "$ROOT_DIR/install.sh" && -f "$ROOT_DIR/config/defaults.conf" ]] || { printf 'Installer archive is incomplete.\n' >&2; exit 1; }
bash "$ROOT_DIR/install.sh" "$@"
status=$?
exit "$status"
