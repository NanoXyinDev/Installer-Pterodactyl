#!/usr/bin/env bash
set -euo pipefail

THEME_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../themes/panel" && pwd)/theme.css"
THEME_PATH="public/zxvcode-panel.css"

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

backup_theme_files() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local out="/var/backups/zxvcode-ptero/theme-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$out"
  [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]] && cp -a "$panel/resources/views/templates/wrapper.blade.php" "$out/wrapper.blade.php"
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && cp -a "$panel/resources/views/layouts/base.blade.php" "$out/base.blade.php"
  [[ -f "$panel/resources/views/layouts/app.blade.php" ]] && cp -a "$panel/resources/views/layouts/app.blade.php" "$out/app.blade.php"
  [[ -f "$panel/$THEME_PATH" ]] && cp -a "$panel/$THEME_PATH" "$out/theme.css"
  [[ -d "$panel/public/zxvcode" ]] && cp -a "$panel/public/zxvcode" "$out/zxvcode"
  ui_success "Theme backup saved to $out."
}

install_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -d "$panel" ]] || { ui_error 'Pterodactyl Panel was not found.'; return 1; }
  [[ -f "$THEME_SOURCE" ]] || { ui_error 'Theme source is missing from the installer.'; return 1; }

  local layouts=()
  [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]] && layouts+=("$panel/resources/views/templates/wrapper.blade.php")
  [[ -f "$panel/resources/views/layouts/admin.blade.php" ]] && layouts+=("$panel/resources/views/layouts/admin.blade.php")
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && layouts+=("$panel/resources/views/layouts/base.blade.php")
  [[ -f "$panel/resources/views/layouts/app.blade.php" ]] && layouts+=("$panel/resources/views/layouts/app.blade.php")
  [[ ${#layouts[@]} -gt 0 ]] || {
    ui_error 'Supported Panel layouts were not found.'
    ui_info 'Checked templates/wrapper.blade.php, layouts/admin.blade.php, layouts/base.blade.php and layouts/app.blade.php.'
    return 1
  }

  backup_theme_files
  mkdir -p "$panel/public"
  install -m 0644 "$THEME_SOURCE" "$panel/$THEME_PATH"
  install_branding_assets

  python3 - "${layouts[@]}" <<'PYTHON'
from pathlib import Path
import sys

css = """    <link rel=\"stylesheet\" href=\"{{ asset('zxvcode-panel.css') }}\">\n"""
brand = """    <div class=\"zxv-protect-brand\" aria-label=\"ZXV PROTECT\">
        <img src=\"{{ asset('zxvcode/mark.svg') }}\" alt=\"ZXV PROTECT\">
        <span><strong>ZXV PROTECT</strong><small>SECURE PANEL</small></span>
    </div>

    @if(Auth::check())
    @php
        $zxvHour = now()->hour;
        $zxvGreeting = $zxvHour >= 5 && $zxvHour < 11 ? 'SELAMAT PAGI' : ($zxvHour >= 11 && $zxvHour < 15 ? 'SELAMAT SIANG' : ($zxvHour >= 15 && $zxvHour < 18 ? 'SELAMAT SORE' : 'SELAMAT MALAM'));
    @endphp
    <div id=\"zxv-welcome-toast\" class=\"zxv-welcome-toast\" role=\"status\" aria-live=\"polite\" aria-atomic=\"true\">
        <div class=\"zxv-welcome-icon\" aria-hidden=\"true\">😊</div>
        <div class=\"zxv-welcome-copy\">
            <strong>HALLO {{ Auth::user()->username }} 😊</strong>
            <span>{{ $zxvGreeting }} • SELAMAT DATANG DI PROJECT ZXV PROTECT 👋</span>
        </div>
        <button type=\"button\" class=\"zxv-welcome-close\" aria-label=\"Tutup notifikasi\">×</button>
    </div>
    <script>
    (() => {
        const syncServerTheme = () => {
            const path = window.location.pathname.replace(/\/+$/, '') || '/';
            const isServer = /^\/server\//.test(path);
            const isDashboard = path === '/' || path === '/dashboard';
            document.body.classList.toggle('zxv-server-theme', isServer);
            document.body.classList.toggle('zxv-dashboard-theme', isDashboard);
        };
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;
        history.pushState = function () {
            const result = originalPushState.apply(this, arguments);
            window.dispatchEvent(new Event('zxv:routechange'));
            return result;
        };
        history.replaceState = function () {
            const result = originalReplaceState.apply(this, arguments);
            window.dispatchEvent(new Event('zxv:routechange'));
            return result;
        };
        window.addEventListener('popstate', syncServerTheme);
        window.addEventListener('zxv:routechange', syncServerTheme);
        syncServerTheme();

        const toast = document.getElementById('zxv-welcome-toast');
        if (!toast) return;
        const key = 'zxv-protect-welcome-v2-{{ Auth::id() }}';
        const close = () => {
            toast.classList.remove('is-visible');
            toast.classList.add('is-closing');
            window.setTimeout(() => toast.remove(), 260);
        };
        const show = () => {
            toast.classList.add('is-visible');
            window.setTimeout(close, 6500);
        };
        toast.querySelector('.zxv-welcome-close')?.addEventListener('click', close);
        try {
            if (sessionStorage.getItem(key) === '1') return;
            sessionStorage.setItem(key, '1');
        } catch (_) {}
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', show, { once: true });
        } else {
            show();
        }
    })();
    </script>
    @endif
"""

changed = 0
for raw in sys.argv[1:]:
    path = Path(raw)
    text = path.read_text(encoding='utf-8')
    original = text
    if 'zxvcode-panel.css' not in text and '</head>' in text:
        text = text.replace('</head>', css + '</head>', 1)
    if 'zxv-protect-brand' not in text:
        pos = text.find('<body')
        if pos >= 0:
            end = text.find('>', pos)
            if end >= 0:
                text = text[:end + 1] + '\n' + brand + text[end + 1:]

    # Give the browser tab and metadata a consistent ZXV PROTECT identity.
    import re
    if not re.search(r'<title>\s*ZXV PROTECT\s*</title>', text, re.I):
        title_re = re.compile(r'<title>.*?</title>', re.I | re.S)
        if title_re.search(text):
            text = title_re.sub('<title>ZXV PROTECT</title>', text, count=1)
        elif '</head>' in text:
            text = text.replace('</head>', '<title>ZXV PROTECT</title>\n</head>', 1)
    if 'name=\"theme-color\"' not in text.lower() and '</head>' in text:
        text = text.replace('</head>', '<meta name=\"theme-color\" content=\"#071225\">\n</head>', 1)
    if 'zxvcode/mark.svg' not in text[:4000] and '</head>' in text:
        text = text.replace('</head>', '<link rel="icon" type="image/svg+xml" href="{{ asset(\'zxvcode/mark.svg\') }}">\n</head>', 1)

    if text != original:
        path.write_text(text, encoding='utf-8')
        changed += 1
print(f'updated {changed} panel layout(s)')
if changed == 0:
    raise SystemExit('no panel layouts were updated')
PYTHON

  chown www-data:www-data "$panel/$THEME_PATH" 2>/dev/null || true
  chown -R www-data:www-data "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan config:clear >/dev/null 2>&1) || true
  ui_success "Premium dark theme + ZXV PROTECT branding installed across ${#layouts[@]} supported Panel layout(s)."
  ui_info 'Client and admin/legacy Blade layouts are styled; a frontend rebuild is not required for this standalone theme.'
}

theme_menu() {
  while true; do
    ui_section 'PANEL APPEARANCE'
    printf '  [01] Apply premium dark theme + ZXV PROTECT branding\n  [02] Backup current theme files\n  [03] Rebuild frontend assets\n  [00] Back\n\n'
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
  if command -v yarn >/dev/null 2>&1; then
    yarn build:production
  elif [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    npm run build:production
  else
    ui_error 'Neither Yarn nor npm is available for frontend build.'
    return 1
  fi
  ui_success 'Panel frontend assets rebuilt.'
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
  ui_success 'ZXV PROTECT branding assets installed.'
}
