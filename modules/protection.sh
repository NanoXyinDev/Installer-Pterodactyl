#!/usr/bin/env bash
set -euo pipefail
PROTECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../protect" && pwd)"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"

protect_entries(){ awk -F '\t' 'NF>=5{print $1"\t"$2"\t"$3"\t"$4"\t"$5}' "$PROTECT_ROOT/manifest.tsv"; }

protect_install_one(){
  local id="$1" row name dest rel sha src tmp actual_sha
  row="$(awk -F '\t' -v id="$id" '$1==id{print; exit}' "$PROTECT_ROOT/manifest.tsv")"
  [[ -n "$row" ]] || { ui_error "Protection $id not found."; return 1; }
  IFS=$'\t' read -r _ name dest rel sha <<< "$row"
  src="$PROTECT_ROOT/$rel"
  [[ -f "$src" ]] || { ui_error "Payload missing: $rel"; return 1; }
  [[ -n "$sha" && "$sha" != "-" ]] || { ui_error "Checksum missing: $name"; return 1; }
  actual_sha="$(sha256sum -- "$src" | awk '{print $1}')"
  [[ "$actual_sha" == "$sha" ]] || { ui_error "Checksum mismatch: $name"; return 1; }
  if [[ "$dest" == /var/www/pterodactyl/* ]]; then
    dest="$PANEL_DIR/${dest#/var/www/pterodactyl/}"
  fi
  mkdir -p "$(dirname "$dest")"
  backup_file "$dest" >/dev/null
  tmp="$(mktemp)"
  cp -- "$src" "$tmp"
  if [[ "$dest" == *.php ]]; then
    php -l "$tmp" >/dev/null || { rm -f "$tmp"; ui_error "PHP syntax check failed: $name"; return 1; }
  fi
  install -m 0644 -- "$tmp" "$dest"
  rm -f "$tmp"
  ui_success "$name"
}

install_protection(){
  require_root
  if [[ ! -f "$PANEL_DIR/artisan" ]]; then
    ui_error "Pterodactyl Panel is not installed at $PANEL_DIR."
    ui_warning 'Protection payloads were not installed. Install the Panel first.'
    return 1
  fi
  ui_section 'PROTECTION ENGINE'
  ui_info 'Source manifest: 23 payloads grouped under PROTECT1 through PROTECT14.'
  local row id count=0 failed=0
  while IFS=$'\t' read -r id name dest rel sha; do
    [[ -n "$id" ]] || continue
    if protect_install_one "$id"; then count=$((count+1)); else failed=$((failed+1)); fi
  done < "$PROTECT_ROOT/manifest.tsv"
  (cd "$PANEL_DIR" && php artisan optimize:clear) >/dev/null 2>&1 || true
  ui_success "Installed $count protection payloads. Failed: $failed."
  if (( failed == 0 )); then
    ui_success 'All manifest entries installed successfully. No PROTECT15 handler exists in the supplied source.'
  else
    ui_warning 'Review failed payloads above; a missing file or source mismatch is not treated as PROTECT15.'
  fi
}

protection_menu(){
  while true; do
    ui_section 'PROTECTION MANAGER'
    printf '  [01] Install Protect All\n  [02] List protection payloads\n  [03] Backup status\n  [00] Back\n\n'
    read -r -p '  Select › ' p
    case "$p" in
      1) install_protection;;
      2) protect_entries | while IFS=$'\t' read -r id name dest rel sha; do printf '  [%02d] %-52s %s\n' "$id" "$name" "$dest"; done;;
      3) if [[ -d /var/backups/zxvcode-ptero ]]; then find /var/backups/zxvcode-ptero -type f | wc -l | xargs printf '  Backups: %s\n'; else ui_warning 'No backups yet.'; fi;;
      0|00) return;;
      *) ui_warning 'Unknown option.';;
    esac
  done
}
