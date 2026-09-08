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
  [[ -f "$panel/resources/views/layouts/admin.blade.php" ]] && cp -a "$panel/resources/views/layouts/admin.blade.php" "$out/admin.blade.php"
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
        const dashboardCards = () => Array.from(document.querySelectorAll('main a[href^="/server/"]'));
        const parseUsage = (text) => {
            const values = [];
            const re = /(?:^|\s)(100|[0-9]{1,2})(?:\s*%)/g;
            let match;
            while ((match = re.exec(text)) && values.length < 3) values.push(Math.min(100, Number(match[1])));
            return values;
        };
        const serverStatus = (card) => {
            const text = card.textContent || '';
            const classes = card.className || '';
            if (/\b(offline|stopped|failed|crashed)\b/i.test(text) || /(text-red-|bg-red-)/i.test(classes)) return { label: 'Offline', state: 'offline' };
            if (/\b(installing|starting|stopping|restarting|transferring|suspended)\b/i.test(text) || /(text-yellow-|bg-yellow-|text-amber-|bg-amber-)/i.test(classes)) return { label: 'Busy', state: 'busy' };
            if (/\b(online|running|active|started)\b/i.test(text) || /(text-green-|bg-green-)/i.test(classes)) return { label: 'Online', state: 'online' };
            return { label: 'Ready', state: 'ready' };
        };
        const serverName = (card, index) => {
            const heading = card.querySelector('h1, h2, h3, h4, [class*="font-semibold"], [class*="font-bold"]');
            const value = heading?.textContent?.trim();
            return value && value.length < 70 ? value : `Server ${index + 1}`;
        };
        const renderDashboardOverview = () => {
            const root = document.querySelector('main');
            if (!root) return;
            const cards = dashboardCards();
            const existing = root.querySelector('.zxv-dashboard-overview');
            if (!cards.length) {
                existing?.remove();
                return;
            }
            const data = cards.map((card, index) => ({
                name: serverName(card, index),
                usage: parseUsage(card.textContent || ''),
                status: serverStatus(card)
            }));
            const online = data.filter((item) => item.status.state === 'online').length;
            const busy = data.filter((item) => item.status.state === 'busy').length;
            const offline = data.length - online - busy;
            const totalUsage = data.flatMap((item) => item.usage);
            const avg = totalUsage.length ? Math.round(totalUsage.reduce((a, b) => a + b, 0) / totalUsage.length) : 0;
            const max = totalUsage.length ? Math.max(...totalUsage) : 0;
            const rows = data.slice(0, 10).map((item) => {
                const v = item.usage.length ? Math.max(...item.usage) : 0;
                return `<div class="zxv-bar-row"><div class="zxv-bar-label"><span title="${item.name.replace(/"/g, '&quot;')}">${item.name.replace(/[&<>]/g, '')}</span><b>${v}%</b></div><div class="zxv-bar-track"><i style="width:${v}%"></i></div></div>`;
            }).join('');
            const statusRows = data.slice(0, 7).map((item) => `<div class="zxv-status-row"><span class="zxv-status-dot ${item.status.state}"></span><span>${item.name.replace(/[&<>]/g, '')}</span><b>${item.status.label}</b></div>`).join('');
            const html = `<section class="zxv-dashboard-overview" aria-label="Ringkasan server">
                <div class="zxv-overview-head"><div><span class="zxv-kicker">ZXV PROTECT</span><h2>Ringkasan server</h2><p>Pantauan singkat dari server yang terlihat di dashboard.</p></div><span class="zxv-live-pill"><span></span> LIVE</span></div>
                <div class="zxv-stat-grid">
                  <div class="zxv-stat-card"><small>Total Server</small><strong>${data.length}</strong><span>server terdaftar</span></div>
                  <div class="zxv-stat-card"><small>Online</small><strong>${online}</strong><span>${busy ? `${busy} sedang diproses` : 'semua yang aktif siap dipakai'}</span></div>
                  <div class="zxv-stat-card"><small>Offline</small><strong>${offline}</strong><span>perlu perhatian</span></div>
                  <div class="zxv-stat-card"><small>Rata-rata Resource</small><strong>${avg}%</strong><span>puncak ${max}% dari data yang tampil</span></div>
                </div>
                <div class="zxv-overview-grid">
                  <div class="zxv-chart-card"><div class="zxv-card-heading"><div><small>RESOURCE SNAPSHOT</small><strong>Grafik pemakaian per server</strong></div><span>${data.length} server</span></div><div class="zxv-bars">${rows}</div></div>
                  <div class="zxv-status-card"><div class="zxv-card-heading"><div><small>STATUS</small><strong>Kondisi server</strong></div><span class="zxv-status-total">${online + busy}/${data.length}</span></div><div class="zxv-status-list">${statusRows}</div></div>
                </div>
            </section>`;
            if (!existing) root.insertAdjacentHTML('afterbegin', html);
            else existing.outerHTML = html;
        };
        const markDashboardCards = () => {
            dashboardCards().forEach((link) => {
                link.classList.add('zxv-server-card');
                if (!link.querySelector('.zxv-card-status')) {
                    const status = serverStatus(link);
                    const chip = document.createElement('span');
                    chip.className = `zxv-card-status ${status.state}`;
                    chip.innerHTML = `<span></span>${status.label}`;
                    link.appendChild(chip);
                }
            });
            document.querySelectorAll('main input, main select').forEach((el) => el.classList.add('zxv-dashboard-control'));
            renderDashboardOverview();
        };
        const syncServerTheme = () => {
            const path = window.location.pathname.replace(/\/+$/, '') || '/';
            const isServer = /^\/server\//.test(path);
            const isDashboard = path === '/' || path === '/dashboard';
            document.body.classList.toggle('zxv-server-theme', isServer);
            document.body.classList.toggle('zxv-dashboard-theme', isDashboard);
            if (isDashboard) window.requestAnimationFrame(markDashboardCards);
            else document.querySelector('.zxv-dashboard-overview')?.remove();
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
        const dashboardObserver = new MutationObserver(() => {
            if (document.body.classList.contains('zxv-dashboard-theme')) markDashboardCards();
        });
        dashboardObserver.observe(document.body, { childList: true, subtree: true });

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
  ui_success "Tema ZXV PROTECT sudah dipasang di ${#layouts[@]} layout Panel yang tersedia."
  ui_info 'Tema dashboard server-list dan halaman server ada di themes/panel/theme.css, lalu dipasang ke public/zxvcode-panel.css. Tidak mengganti komponen React Panel.'
}

theme_menu() {
  while true; do
    ui_section 'TAMPILAN PANEL'
    printf '  [01] Pasang / update tema\n  [02] Rebuild frontend lalu pasang lagi\n  [03] Hapus tema\n  [04] Backup tema\n  [00] Kembali\n\n'
    read -r -p '  Pilih yang mau dilakukan › ' choice
    case "$choice" in
      1|01) install_theme ;;
      2|02) rebuild_and_apply_theme ;;
      3|03) uninstall_theme ;;
      4|04) backup_theme_files ;;
      0|00) return ;;
      *) ui_warning 'Pilihan itu belum ada. Pilih nomor yang tersedia ya.' ;;
    esac
  done
}

build_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl tidak ditemukan.'; return 1; }
  cd "$panel"
  ui_info 'Frontend sedang dibangun ulang. Ini bisa butuh beberapa menit.'
  if [[ -f package.json ]] && command -v yarn >/dev/null 2>&1; then
    yarn build:production
  elif [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    npm run build:production
  else
    ui_error 'Yarn atau npm tidak ditemukan, jadi frontend belum bisa dibuild ulang.'
    return 1
  fi
  ui_success 'Frontend selesai dibangun ulang. Tema tidak ikut hilang karena dipasang sebagai stylesheet terpisah.'
}

rebuild_and_apply_theme() {
  if build_theme; then
    ui_info 'Frontend sudah beres. Sekarang gue terapkan ulang tema supaya tampilan dashboard dan server tetap kepakai.'
    install_theme
    ui_success 'Selesai. Tema ZXV PROTECT sudah diterapkan lagi setelah rebuild.'
  fi
}

uninstall_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local backup_root="/var/backups/zxvcode-ptero"
  local latest=""
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl tidak ditemukan.'; return 1; }

  if compgen -G "$backup_root/theme-*" >/dev/null 2>&1; then
    latest="$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name 'theme-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
  fi

  if [[ -n "$latest" && -d "$latest" ]]; then
    ui_info "Gue menemukan cadangan tema terakhir: $(basename "$latest")."
    [[ -f "$latest/wrapper.blade.php" ]] && install -m 0644 "$latest/wrapper.blade.php" "$panel/resources/views/templates/wrapper.blade.php"
    [[ -f "$latest/admin.blade.php" ]] && install -m 0644 "$latest/admin.blade.php" "$panel/resources/views/layouts/admin.blade.php"
    [[ -f "$latest/base.blade.php" ]] && install -m 0644 "$latest/base.blade.php" "$panel/resources/views/layouts/base.blade.php"
    [[ -f "$latest/app.blade.php" ]] && install -m 0644 "$latest/app.blade.php" "$panel/resources/views/layouts/app.blade.php"
    ui_success 'File layout dikembalikan ke kondisi sebelum tema terakhir dipasang.'
  else
    ui_warning 'Cadangan tema tidak ditemukan. Gue hanya membersihkan file dan tanda tema yang memang dibuat installer.'
    python3 - "$panel" <<'PYTHON'
from pathlib import Path
import re, sys
panel = Path(sys.argv[1])
paths = [
    panel / 'resources/views/templates/wrapper.blade.php',
    panel / 'resources/views/layouts/admin.blade.php',
    panel / 'resources/views/layouts/base.blade.php',
    panel / 'resources/views/layouts/app.blade.php',
]
for path in paths:
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    text = text.replace('    <link rel="stylesheet" href="{{ asset(\'zxvcode-panel.css\') }}">\n', '')
    text = re.sub(r'\n\s*<div class="zxv-protect-brand".*?</div>\s*', '\n', text, flags=re.S)
    toast = re.compile(r'@if\(Auth::check\(\)\).*?id=\"zxv-welcome-toast\".*?@endif\s*', re.S)
    text = toast.sub('\n', text, count=1)
    text = re.sub(r'\n\s*<meta name="theme-color" content="#071225">\s*', '\n', text)
    text = re.sub(r'\n\s*<link rel="icon" type="image/svg\+xml" href="\{\{ asset\(\'zxvcode/mark\.svg\'\) \}\}">\s*', '\n', text)
    text = re.sub(r'<title>ZXV PROTECT</title>', '', text, count=1, flags=re.I)
    path.write_text(text, encoding='utf-8')
PYTHON
  fi

  rm -f "$panel/$THEME_PATH"
  rm -f "$panel/public/zxvcode/mark.svg"
  rmdir "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan config:clear >/dev/null 2>&1) || true
  ui_success 'Tema ZXV PROTECT sudah dilepas. Dashboard dan server list kembali memakai tampilan bawaan Panel.'
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
