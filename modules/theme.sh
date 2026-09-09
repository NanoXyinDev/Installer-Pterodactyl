#!/usr/bin/env bash
set -euo pipefail

THEME_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../themes/panel" && pwd)/theme.css"
THEME_PATH="public/zxvcode-panel.css"
THEME_JS_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../themes/panel" && pwd)/theme.js"
THEME_JS_PATH="public/zxvcode-panel.js"
THEME_BACKUP_ROOT="/var/backups/zxvcode-ptero"

find_panel_layout() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  if [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]]; then
    printf '%s\n' "$panel/resources/views/templates/wrapper.blade.php"
  elif [[ -f "$panel/resources/views/layouts/base.blade.php" ]]; then
    printf '%s\n' "$panel/resources/views/layouts/base.blade.php"
  elif [[ -f "$panel/resources/views/layouts/app.blade.php" ]]; then
    printf '%s\n' "$panel/resources/views/layouts/app.blade.php"
  fi
}

theme_active() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -f "$panel/$THEME_PATH" ]] && return 0
  grep -RqsE 'ZXV PROTECT:ASSETS|zxvcode-panel\.css|zxvcode-panel\.js' \
    "$panel/resources/views/templates/wrapper.blade.php" \
    "$panel/resources/views/layouts/admin.blade.php" \
    "$panel/resources/views/layouts/base.blade.php" \
    "$panel/resources/views/layouts/app.blade.php" 2>/dev/null
}

create_theme_snapshot() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local prefix="${1:-theme-snapshot}"
  local out="$THEME_BACKUP_ROOT/${prefix}-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]] && cp -a "$panel/resources/views/templates/wrapper.blade.php" "$out/wrapper.blade.php"
  [[ -f "$panel/resources/views/layouts/admin.blade.php" ]] && cp -a "$panel/resources/views/layouts/admin.blade.php" "$out/admin.blade.php"
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && cp -a "$panel/resources/views/layouts/base.blade.php" "$out/base.blade.php"
  [[ -f "$panel/resources/views/layouts/app.blade.php" ]] && cp -a "$panel/resources/views/layouts/app.blade.php" "$out/app.blade.php"
  [[ -f "$panel/$THEME_PATH" ]] && cp -a "$panel/$THEME_PATH" "$out/theme.css"
  [[ -d "$panel/public/zxvcode" ]] && cp -a "$panel/public/zxvcode" "$out/zxvcode"
  ui_success "Cadangan tema disimpan di $out."
}

create_theme_baseline() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local baseline="$THEME_BACKUP_ROOT/theme-baseline"
  [[ -d "$baseline" ]] && return 0
  mkdir -p "$baseline"
  [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]] && cp -a "$panel/resources/views/templates/wrapper.blade.php" "$baseline/wrapper.blade.php"
  [[ -f "$panel/resources/views/layouts/admin.blade.php" ]] && cp -a "$panel/resources/views/layouts/admin.blade.php" "$baseline/admin.blade.php"
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && cp -a "$panel/resources/views/layouts/base.blade.php" "$baseline/base.blade.php"
  [[ -f "$panel/resources/views/layouts/app.blade.php" ]] && cp -a "$panel/resources/views/layouts/app.blade.php" "$baseline/app.blade.php"
  ui_info 'Gue simpan kondisi Panel sebelum theme dipasang, jadi nanti bisa dibalikin tanpa nyari backup yang salah.'
}

save_theme_state() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local baseline="$THEME_BACKUP_ROOT/theme-baseline"
  local state="$baseline/state.tsv"
  mkdir -p "$baseline"
  : > "$state"
  for path in \
    "$panel/resources/views/templates/wrapper.blade.php" \
    "$panel/resources/views/layouts/admin.blade.php" \
    "$panel/resources/views/layouts/base.blade.php" \
    "$panel/resources/views/layouts/app.blade.php"; do
    [[ -f "$path" ]] || continue
    printf '%s\t%s\n' "${path#$panel/}" "$(sha256sum "$path" | awk '{print $1}')" >> "$state"
  done
}

backup_theme_files() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl tidak ditemukan.'; return 1; }
  create_theme_snapshot "theme-snapshot"
}

restore_theme_baseline() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local baseline="$THEME_BACKUP_ROOT/theme-baseline"
  if [[ -d "$baseline" ]] && [[ -f "$baseline/wrapper.blade.php" || -f "$baseline/admin.blade.php" || -f "$baseline/base.blade.php" || -f "$baseline/app.blade.php" ]]; then
    [[ -f "$baseline/wrapper.blade.php" ]] && install -m 0644 "$baseline/wrapper.blade.php" "$panel/resources/views/templates/wrapper.blade.php"
    [[ -f "$baseline/admin.blade.php" ]] && install -m 0644 "$baseline/admin.blade.php" "$panel/resources/views/layouts/admin.blade.php"
    [[ -f "$baseline/base.blade.php" ]] && install -m 0644 "$baseline/base.blade.php" "$panel/resources/views/layouts/base.blade.php"
    [[ -f "$baseline/app.blade.php" ]] && install -m 0644 "$baseline/app.blade.php" "$panel/resources/views/layouts/app.blade.php"
    ui_success 'Panel sudah dikembalikan ke kondisi sebelum theme dipasang.'
    return 0
  fi
  return 1
}

install_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local state_dir="$THEME_BACKUP_ROOT/theme-state"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl belum ketemu. Coba cek dulu lokasi Panel-nya.'; return 1; }
  [[ -f "$THEME_SOURCE" ]] || { ui_error 'File theme belum ada di paket installer ini.'; return 1; }

  local layouts=()
  for candidate in \
    "$panel/resources/views/templates/wrapper.blade.php" \
    "$panel/resources/views/layouts/admin.blade.php" \
    "$panel/resources/views/layouts/base.blade.php" \
    "$panel/resources/views/layouts/app.blade.php"; do
    [[ -f "$candidate" ]] && layouts+=("$candidate")
  done
  [[ ${#layouts[@]} -gt 0 ]] || {
    ui_error 'Gue belum menemukan layout Panel yang cocok untuk dipasang theme.'
    ui_info 'Yang gue cari: templates/wrapper.blade.php, layouts/admin.blade.php, layouts/base.blade.php, atau layouts/app.blade.php.'
    return 1
  }

  mkdir -p "$THEME_BACKUP_ROOT" "$state_dir"
  local stamp="$(date +%Y%m%d-%H%M%S)"
  local tx="$THEME_BACKUP_ROOT/install-$stamp"
  mkdir -p "$tx/layouts"
  for path in "${layouts[@]}"; do
    cp -a "$path" "$tx/layouts/$(basename "$path")"
  done

  ui_info 'Gue cek Panel dulu sebelum menyentuh file apa pun.'
  if ! (cd "$panel" && php artisan --version >/dev/null 2>&1); then
    ui_error 'Panel-nya belum bisa dipanggil lewat Artisan. Gue berhenti di sini supaya tidak bikin Panel makin bermasalah.'
    rm -rf "$tx"
    return 1
  fi

  ui_info 'Oke, Panel aman. Sekarang gue bersihin sisa greeting lama sebelum pasang yang baru.'
  cleanup_legacy_greeting "${layouts[@]}"
  ui_info 'Sekarang gue pasang theme tanpa mengubah komponen React bawaan.'
  mkdir -p "$panel/public/zxvcode"
  install -m 0644 "$THEME_SOURCE" "$panel/$THEME_PATH"
  install -m 0644 "$THEME_JS_SOURCE" "$panel/$THEME_JS_PATH"
  install_branding_assets

  local theme_version
  theme_version="$(date +%Y%m%d%H%M%S)"
  if ! python3 - "$theme_version" "${layouts[@]}" <<'PYTHON'
from pathlib import Path
import re, sys

version = sys.argv[1]
css_tag = f'<link rel="stylesheet" href="/zxvcode-panel.css?v={version}">'
js_tag = f'<script src="/zxvcode-panel.js?v={version}" defer></script>'
marker = '<!-- ZXV PROTECT:ASSETS -->'
end_marker = '<!-- ZXV PROTECT:ASSETS END -->'
block = f'    {marker}\n    {css_tag}\n    {js_tag}\n    {end_marker}\n'

changed = 0
for raw in sys.argv[2:]:
    path = Path(raw)
    text = path.read_text(encoding='utf-8')
    original = text
    text = re.sub(r'\s*<!-- ZXV PROTECT:ASSETS -->.*?<!-- ZXV PROTECT:ASSETS END -->\s*', '\n', text, flags=re.S)
    text = re.sub(r'<link rel="stylesheet" href="/zxvcode-panel\.css(?:\?v=[^"]+)?">\s*', '', text)
    text = re.sub(r'<script src="/zxvcode-panel\.js(?:\?v=[^"]+)?" defer></script>\s*', '', text)
    if '</head>' not in text.lower():
        continue
    match = re.search(r'</head>', text, flags=re.I)
    pos = match.start()
    text = text[:pos] + block + text[pos:]
    if text != original:
        path.write_text(text, encoding='utf-8')
        changed += 1
print(f'updated {changed} panel layout(s)')
if changed == 0:
    raise SystemExit('Tidak ada layout yang bisa diperbarui.')
PYTHON
  then
    ui_error 'Pemasangan theme tidak bisa diselesaikan. File Panel gue biarkan seperti semula.'
    rm -rf "$tx"
    rm -f "$panel/$THEME_PATH" "$panel/$THEME_JS_PATH" "$panel/public/zxvcode/mark.svg"
    rmdir "$panel/public/zxvcode" 2>/dev/null || true
    return 1
  fi

  ui_info 'Theme sudah masuk. Sekarang gue cek Blade supaya tidak ada kejutan 500.'
  if ! (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan view:cache >/dev/null 2>&1); then
    ui_error 'Pemeriksaan Blade gagal. Gue balikin file Panel ke kondisi sebelum pemasangan.'
    for path in "${layouts[@]}"; do
      base="$(basename "$path")"
      [[ -f "$tx/layouts/$base" ]] && install -m 0644 "$tx/layouts/$base" "$path"
    done
    rm -f "$panel/$THEME_PATH" "$panel/$THEME_JS_PATH" "$panel/public/zxvcode/mark.svg"
    rmdir "$panel/public/zxvcode" 2>/dev/null || true
    (cd "$panel" && php artisan view:clear >/dev/null 2>&1) || true
    rm -rf "$tx"
    return 1
  fi

  : > "$state_dir/layouts.tsv"
  for path in "${layouts[@]}"; do
    printf '%s\t%s\n' "${path#$panel/}" "$(sha256sum "$path" | awk '{print $1}')" >> "$state_dir/layouts.tsv"
  done
  printf '%s\n' "$stamp" > "$state_dir/last_install"
  printf '%s\n' "$stamp" > "$state_dir/baseline_backup"
  mkdir -p "$THEME_BACKUP_ROOT/theme-${stamp}"
  cp -a "$tx/layouts/." "$THEME_BACKUP_ROOT/theme-${stamp}/" 2>/dev/null || true

  chown www-data:www-data "$panel/$THEME_PATH" "$panel/$THEME_JS_PATH" 2>/dev/null || true
  chown -R www-data:www-data "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1) || true
  rm -rf "$tx"

  ui_success 'Sip, theme sudah terpasang. Gue juga sudah cek Blade dan tidak menemukan error dari file theme.'
  ui_info 'Dashboard, daftar server, halaman server, console, form, tabel, dan halaman admin sekarang memakai tampilan ZXV PROTECT.'
}

theme_menu() {
  while true; do
    ui_section 'ATUR TAMPILAN PANEL'
    printf '  [ + ] 1. Pasang / Update Theme\n  [ + ] 2. Build & Pasang Lagi\n  [ + ] 3. Lepas Theme\n  [ + ] 4. Backup Theme\n  [ + ] 0. Kembali\n\n'
    read -r -p '  Pilih › ' choice
    case "$choice" in
      1|01) install_theme ;;
      2|02) rebuild_and_apply_theme ;;
      3|03) uninstall_theme ;;
      4|04) backup_theme_files ;;
      0|00) return ;;
      *) ui_warning 'Pilihan itu belum ada. Pilih nomor yang terlihat di atas.' ;;
    esac
  done
}

remove_theme_markers() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  python3 - "$panel" <<'PYTHON'
from pathlib import Path
import re, sys
panel = Path(sys.argv[1])
paths = [panel / 'resources/views/templates/wrapper.blade.php', panel / 'resources/views/layouts/admin.blade.php', panel / 'resources/views/layouts/base.blade.php', panel / 'resources/views/layouts/app.blade.php']
for path in paths:
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'\s*<!-- ZXV PROTECT:ASSETS -->.*?<!-- ZXV PROTECT:ASSETS END -->\s*', '\n', text, flags=re.S)
    text = text.replace('<link rel="stylesheet" href="/zxvcode-panel.css">\n', '')
    text = text.replace('<script src="/zxvcode-panel.js" defer></script>\n', '')
    path.write_text(text, encoding='utf-8')
PYTHON
}

uninstall_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local state_dir="$THEME_BACKUP_ROOT/theme-state"
  local state="$state_dir/layouts.tsv"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel belum ketemu.'; return 1; }

  ui_info 'Gue cek dulu file mana yang benar-benar masih sama seperti saat theme dipasang.'
  local restored=0
  if [[ -f "$state" ]]; then
    while IFS=$'\t' read -r rel expected; do
      [[ -n "$rel" && -n "$expected" ]] || continue
      current="$panel/$rel"
      [[ -f "$current" ]] || continue
      actual="$(sha256sum "$current" | awk '{print $1}')"
      [[ "$actual" == "$expected" ]] || continue
      # Reconstruct a clean copy by removing only our asset block.
      python3 - "$current" <<'PYTHON'
from pathlib import Path
import re, sys
p=Path(sys.argv[1])
t=p.read_text(encoding='utf-8')
t=re.sub(r'\s*<!-- ZXV PROTECT:ASSETS -->.*?<!-- ZXV PROTECT:ASSETS END -->\s*', '\n', t, flags=re.S)
t=re.sub(r'<link rel="stylesheet" href="/zxvcode-panel\.css(?:\?v=[^"]+)?">\s*','',t)
t=re.sub(r'<script src="/zxvcode-panel\.js(?:\?v=[^"]+)?" defer></script>\s*','',t)
p.write_text(t, encoding='utf-8')
PYTHON
      restored=$((restored+1))
    done < "$state"
  else
    remove_theme_markers
  fi

  rm -f "$panel/$THEME_PATH" "$panel/$THEME_JS_PATH" "$panel/public/zxvcode/mark.svg"
  rmdir "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1) || true

  if (( restored > 0 )); then
    ui_success "Theme sudah dilepas. $restored file layout dikembalikan tanpa menyentuh perubahan Panel yang lain."
  else
    ui_success 'Theme sudah dilepas. File Panel yang tidak dikenali sebagai milik theme tidak gue sentuh.'
  fi
  ui_info 'Kalau halaman masih terlihat seperti sebelumnya, coba hard refresh browser setelah login ulang.'
}


cleanup_legacy_greeting() {
  python3 - "$@" <<'PYTHON'
from pathlib import Path
import re, sys
phrases = [
    'HALLO admin',
    'SELAMAT DATANG DI ZXV',
]
for raw in sys.argv[1:]:
    path = Path(raw)
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    for phrase in phrases:
        pattern = re.compile(r'<([A-Za-z][\w:-]*)(?:\s[^>]*)?>\s*' + re.escape(phrase) + r'(?:\s*👋)?\s*</\1>', re.I | re.S)
        text = pattern.sub('', text)
        text = re.sub(r'(?m)^\s*' + re.escape(phrase) + r'(?:\s*👋)?\s*$', '', text, flags=re.I)
    path.write_text(text, encoding='utf-8')
PYTHON
}

install_branding_assets() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}" asset_dir="$panel/public/zxvcode"
  mkdir -p "$asset_dir"
  cat >"$asset_dir/mark.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160" role="img" aria-label="ZXV PROTECT">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#21a7ff"/><stop offset="1" stop-color="#4b5cff"/></linearGradient></defs>
  <path d="M80 8 142 31v43c0 39-25 62-62 78C43 136 18 113 18 74V31z" fill="#071225" stroke="url(#g)" stroke-width="6"/>
  <path d="M42 91c7-28 24-45 51-49 10-1 19 1 26 5-9 4-16 10-20 18 10 2 18 7 24 15-14-3-26-2-36 5-13 8-25 10-45 6z" fill="url(#g)"/>
  <circle cx="96" cy="58" r="5" fill="#fff"/>
  <path d="M53 119h54" stroke="#54baff" stroke-width="4" stroke-linecap="round"/>
</svg>
SVG
  chown -R www-data:www-data "$asset_dir" 2>/dev/null || true
  ui_success 'Logo ZXV PROTECT sudah disiapkan.'
}
