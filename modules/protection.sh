#!/usr/bin/env bash
set -euo pipefail
PROTECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../protect" && pwd)"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"

protect_entries(){ awk -F '\t' 'NF>=5{print $1"\t"$2"\t"$3"\t"$4"\t"$5}' "$PROTECT_ROOT/manifest.tsv"; }

install_primary_admin_guard(){
  local middleware_dir="$PANEL_DIR/app/Http/Middleware"
  local middleware="$middleware_dir/ZxvPrimaryAdminOnly.php"
  local routes="$PANEL_DIR/routes/admin.php"
  mkdir -p "$middleware_dir"

  local runtime_source="$PROTECT_ROOT/runtime/ZxvPrimaryAdminOnly.php"
  [[ -f "$runtime_source" ]] || { ui_error 'Primary admin guard source missing.'; return 1; }
  backup_file "$middleware" >/dev/null
  install -m 0644 "$runtime_source" "$middleware"

  php -l "$middleware" >/dev/null || { ui_error 'Primary admin guard gagal melewati PHP lint.'; return 1; }

  [[ -f "$routes" ]] || { ui_error 'routes/admin.php tidak ditemukan.'; return 1; }
  backup_file "$routes" >/dev/null

  python3 - "$routes" <<'PYTHON'
from pathlib import Path
import re, sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
use_line = 'use Pterodactyl\\Http\\Middleware\\ZxvPrimaryAdminOnly;'
if use_line not in text:
    marker = 'use Illuminate\\Support\\Facades\\Route;'
    if marker in text:
        text = text.replace(marker, marker + '\n' + use_line, 1)
    else:
        text = use_line + '\n' + text

prefixes = ('api', 'locations', 'databases', 'settings', 'nodes', 'mounts', 'nests')
for prefix in prefixes:
    pattern = re.compile(r"Route::group\(\['prefix'\s*=>\s*'" + re.escape(prefix) + r"'([^\]]*)\],\s*function\s*\(\)\s*\{")
    match = pattern.search(text)
    if not match:
        continue
    tail = match.group(1)
    if 'ZxvPrimaryAdminOnly::class' in tail:
        continue
    replacement = "Route::group(['prefix' => '" + prefix + "', 'middleware' => [ZxvPrimaryAdminOnly::class]" + tail + "], function () {"
    text = text[:match.start()] + replacement + text[match.end():]

path.write_text(text, encoding='utf-8')
PYTHON

  if ! grep -q 'ZxvPrimaryAdminOnly::class' "$routes"; then
    ui_error 'Route guard tidak berhasil dipasang.'
    return 1
  fi

  (cd "$PANEL_DIR" && php artisan optimize:clear >/dev/null 2>&1) || true
  ui_success 'Primary-admin route guard aktif untuk area sensitif.'
}

protection_audit(){
  local middleware="$PANEL_DIR/app/Http/Middleware/ZxvPrimaryAdminOnly.php"
  local routes="$PANEL_DIR/routes/admin.php"
  local failures=0
  ui_section 'PROTECTION AUDIT'
  if [[ -f "$middleware" ]] && php -l "$middleware" >/dev/null 2>&1; then
    ui_success 'Primary-admin middleware: OK'
  else
    ui_error 'Primary-admin middleware: MISSING/BROKEN'; failures=$((failures+1))
  fi
  if [[ -f "$routes" ]] && grep -q 'ZxvPrimaryAdminOnly::class' "$routes"; then
    ui_success 'Sensitive admin route guard: OK (primary admin only)'
  else
    ui_error 'Sensitive admin route guard: MISSING'; failures=$((failures+1))
  fi
  if [[ -f "$routes" ]] && grep -q "'prefix' => 'nodes'.*ZxvPrimaryAdminOnly::class" "$routes"; then
    ui_success 'Direct /admin/nodes/view/{id}: protected at route level'
  else
    ui_error 'Direct /admin/nodes/view/{id}: NOT PROTECTED'; failures=$((failures+1))
  fi
  (( failures == 0 )) || return 1
}

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
  ui_info 'Primary-admin guard: user ID 1 only for sensitive admin routes.'
  local row id count=0 failed=0
  while IFS=$'\t' read -r id name dest rel sha; do
    [[ -n "$id" ]] || continue
    if protect_install_one "$id"; then count=$((count+1)); else failed=$((failed+1)); fi
  done < "$PROTECT_ROOT/manifest.tsv"
  (cd "$PANEL_DIR" && php artisan optimize:clear) >/dev/null 2>&1 || true
  ui_success "Installed $count protection payloads. Failed: $failed."
  if install_primary_admin_guard; then
    ui_success 'Direct-route hardening applied; /admin/nodes/view/{id} is no longer hidden-menu-only.'
  else
    failed=$((failed+1))
    ui_warning 'Primary-admin route guard failed. Manifest payloads remain installed, but direct sensitive routes need review.'
  fi
  if (( failed == 0 )); then
    ui_success 'All protection layers installed. No PROTECT15 handler is fabricated.'
  else
    ui_warning 'Review failed protection layers above; missing files and source mismatches are reported explicitly.'
  fi
  if declare -F zxv_roles_install >/dev/null 2>&1; then
    ui_info 'Role system ikut disinkronkan agar guard dan Admin Dashboard tetap satu jalur.'
    zxv_roles_install || ui_warning 'Role system belum tersinkron; jalankan menu Role & Admin Dashboard setelah Panel siap.'
  fi
}

protection_menu(){
  while true; do
    ui_section 'PROTECTION MANAGER'
    printf '  [01] Pasang semua perlindungan\n  [02] Lihat perlindungan yang terpasang\n  [03] Cek guard\n  [04] Cek backup\n  [00] Back\n\n'
    read -r -p '  Select › ' p
    case "$p" in
      1) install_protection;;
      2) protect_entries | while IFS=$'\t' read -r id name dest rel sha; do printf '  [%02d] %-52s %s\n' "$id" "$name" "$dest"; done;;
      3) protection_audit;;
      4) if [[ -d /var/backups/zxvcode-ptero ]]; then find /var/backups/zxvcode-ptero -type f | wc -l | xargs printf '  Jumlah backup: %s\n'; else ui_warning 'Belum ada backup.'; fi;;
      0|00) return;;
      *) ui_warning 'Pilihan itu belum tersedia.';;
    esac
  done
}
