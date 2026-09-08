#!/usr/bin/env bash
set -euo pipefail

THEME_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../themes/panel" && pwd)/theme.css"
THEME_PATH="public/zxvcode-panel.css"

backup_theme_files() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local out="/var/backups/zxvcode-ptero/theme-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && cp -a "$panel/resources/views/layouts/base.blade.php" "$out/base.blade.php"
  [[ -f "$panel/$THEME_PATH" ]] && cp -a "$panel/$THEME_PATH" "$out/theme.css"
  ui_success "Theme backup saved to $out."
}

install_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local layout="$panel/resources/views/layouts/base.blade.php"
  [[ -d "$panel" ]] || { ui_error 'Pterodactyl Panel was not found.'; return 1; }
  [[ -f "$THEME_SOURCE" ]] || { ui_error 'Theme source is missing from the installer.'; return 1; }
  [[ -f "$layout" ]] || { ui_error 'Panel base layout was not found.'; return 1; }

  backup_theme_files
  mkdir -p "$panel/public"
  install -m 0644 "$THEME_SOURCE" "$panel/$THEME_PATH"
  install_branding_assets

  if ! grep -Fq 'zxvcode-panel.css' "$layout"; then
    python3 - "$layout" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
tag = '    <link rel="stylesheet" href="{{ asset(\'zxvcode-panel.css\') }}">\n'
if '</head>' not in text:
    raise SystemExit('base layout has no </head> tag')
text = text.replace('</head>', tag + '</head>', 1)
path.write_text(text)
PY
  fi

  chown www-data:www-data "$panel/$THEME_PATH" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan config:clear >/dev/null 2>&1) || true
  ui_success 'Clean dark panel theme installed.'
  ui_info 'The theme is loaded directly by the Panel layout; no frontend rebuild is required.'
}

theme_menu() {
  while true; do
    ui_section 'PANEL APPEARANCE'
    printf '  [01] Apply clean dark theme\n  [02] Backup current theme files\n  [03] Rebuild frontend assets\n  [00] Back\n\n'
    read -r -p '  Select option › ' choice
    case "$choice" in
      1|01) install_theme ;;
      2|02) backup_theme_files ;;
      3|03) build_theme ;;
      0|00) return ;;
      *) ui_warning 'Unknown option.' ;;
    esac
  done
}

build_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -d "$panel" ]] || { ui_error 'Pterodactyl Panel was not found.'; return 1; }
  cd "$panel"
  command -v yarn >/dev/null 2>&1 || npm install -g yarn
  yarn build:production
  ui_success 'Panel frontend assets rebuilt.'
}

install_branding_assets() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}" asset_dir="$panel/public/zxvcode"
  mkdir -p "$asset_dir"
  cat >"$asset_dir/mark.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" role="img" aria-label="Pterodactyl panel mark">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#8b9cff"/><stop offset="1" stop-color="#42e8b5"/></linearGradient></defs>
  <circle cx="60" cy="60" r="52" fill="#0d1527" stroke="url(#g)" stroke-width="4"/>
  <path d="M31 70c8-25 22-37 42-37 8 0 14 2 19 6-6 2-11 6-14 11 7 1 13 5 17 11-11-2-20-1-28 4-10 6-18 8-36 5z" fill="url(#g)"/>
  <circle cx="73" cy="47" r="4" fill="#fff"/>
</svg>
SVG
  chown -R www-data:www-data "$asset_dir" 2>/dev/null || true
  ui_success 'Panel branding assets installed.'
}
