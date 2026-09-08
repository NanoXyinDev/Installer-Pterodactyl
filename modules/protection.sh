#!/usr/bin/env bash
set -euo pipefail
PROTECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../protect" && pwd)"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
protect_entries(){ awk -F '\t' 'NF>=5{print $1"\t"$2"\t"$3"\t"$4}' "$PROTECT_ROOT/manifest.tsv"; }
protect_install_one(){
  local id="$1" row name dest rel sha src tmp
  row="$(awk -F '\t' -v id="$id" '$1==id{print; exit}' "$PROTECT_ROOT/manifest.tsv")"
  [[ -n "$row" ]] || { ui_error "Protection $id not found."; return 1; }
  IFS=$'\t' read -r _ name dest rel sha <<< "$row"
  src="$PROTECT_ROOT/$rel"; tmp="$(mktemp)"
  [[ -f "$src" ]] || { rm -f "$tmp"; ui_error "Payload missing: $rel"; return 1; }
  [[ -n "$sha" && "$sha" != "-" ]] || { rm -f "$tmp"; ui_error "Checksum missing: $name"; return 1; }
  local actual_sha; actual_sha="$(sha256sum -- "$src" | awk "{print \\$1}")"
  [[ "$actual_sha" == "$sha" ]] || { rm -f "$tmp"; ui_error "Checksum mismatch: $name"; return 1; }
  mkdir -p "$(dirname "$PANEL_DIR${dest#/var/www/pterodactyl}")"
  if [[ "$dest" == /var/www/pterodactyl/* ]]; then dest="$PANEL_DIR/${dest#/var/www/pterodactyl/}"; fi
  mkdir -p "$(dirname "$dest")"
  backup_file "$dest" >/dev/null
  cp -- "$src" "$tmp"
  if [[ "$dest" == *.php ]]; then php -l "$tmp" >/dev/null || { rm -f "$tmp"; ui_error "PHP syntax check failed: $name"; return 1; }; fi
  install -m 0644 -- "$tmp" "$dest"
  rm -f "$tmp"
  ui_success "$name"
}
install_protection(){
  require_root
  ui_section 'PROTECTION ENGINE'
  ui_info 'Bash-native installer; no Telegram bot runtime is used.'
  local row id count=0 failed=0
  while IFS=$'\t' read -r id name dest rel sha; do
    [[ -n "$id" ]] || continue
    if protect_install_one "$id"; then count=$((count+1)); else failed=$((failed+1)); fi
  done < "$PROTECT_ROOT/manifest.tsv"
  (cd "$PANEL_DIR" && php artisan optimize:clear) >/dev/null 2>&1 || true
  ui_success "Installed $count unique protection payloads. Failed: $failed."
  ui_warning 'The source defines PROTECT1 through PROTECT14; no PROTECT15 handler was present in the supplied file.'
}
protection_menu(){
  while true; do
    ui_section 'PROTECTION MANAGER'
    printf '  [01] Install Protect All\n  [02] List protection payloads\n  [03] Backup status\n  [00] Back\n\n'
    read -r -p '  Select › ' p
    case "$p" in
      1) install_protection;;
      2) protect_entries | while IFS=$'\t' read -r id name dest rel; do printf '  [%02d] %-52s %s\n' "$id" "$name" "$dest"; done;;
      3) [[ -d /var/backups/zxvcode-ptero ]] && find /var/backups/zxvcode-ptero -type f | wc -l | xargs printf '  Backups: %s\n' || ui_warning 'No backups yet.';;
      0|00) return;; *) ui_warning 'Unknown option.';;
    esac
  done
}
