#!/usr/bin/env bash
set -euo pipefail

THEME_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../themes/panel" && pwd)/theme.css"
THEME_PATH="public/zxvcode-panel.css"
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
  grep -RqsE 'ZXV PROTECT:THEME|zxv-protect-brand|zxvcode-panel\.css' \
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
  [[ -d "$panel" ]] || { ui_error 'Pterodactyl Panel tidak ditemukan.'; return 1; }
  [[ -f "$THEME_SOURCE" ]] || { ui_error 'File theme tidak ditemukan di installer.'; return 1; }

  local layouts=()
  [[ -f "$panel/resources/views/templates/wrapper.blade.php" ]] && layouts+=("$panel/resources/views/templates/wrapper.blade.php")
  [[ -f "$panel/resources/views/layouts/admin.blade.php" ]] && layouts+=("$panel/resources/views/layouts/admin.blade.php")
  [[ -f "$panel/resources/views/layouts/base.blade.php" ]] && layouts+=("$panel/resources/views/layouts/base.blade.php")
  [[ -f "$panel/resources/views/layouts/app.blade.php" ]] && layouts+=("$panel/resources/views/layouts/app.blade.php")
  [[ ${#layouts[@]} -gt 0 ]] || {
    ui_error 'Layout Panel yang didukung tidak ditemukan.'
    ui_info 'Gue sudah cek templates/wrapper.blade.php, layouts/admin.blade.php, layouts/base.blade.php dan layouts/app.blade.php.'
    return 1
  }

  if ! theme_active; then
    create_theme_baseline
  else
    ui_info 'Theme sudah terpasang. Gue update file yang sekarang tanpa membuat backup bertingkat.'
  fi

  mkdir -p "$panel/public"
  install -m 0644 "$THEME_SOURCE" "$panel/$THEME_PATH"
  install_branding_assets

  python3 - "${layouts[@]}" <<'PYTHON'
from pathlib import Path
import re, sys

css = """    <!-- ZXV PROTECT:THEME CSS -->
    <link rel="stylesheet" href="{{ asset('zxvcode-panel.css') }}">
    <!-- ZXV PROTECT:THEME CSS END -->
"""
body = """    <!-- ZXV PROTECT:THEME BODY -->
    <div class="zxv-protect-brand" aria-label="ZXV PROTECT">
        <img src="{{ asset('zxvcode/mark.svg') }}" alt="ZXV PROTECT">
        <span><strong>ZXV PROTECT</strong><small>SECURE PANEL</small></span>
    </div>

    @if(Auth::check())
    @php
        $zxvHour = now()->hour;
        $zxvGreeting = $zxvHour >= 5 && $zxvHour < 11 ? 'SELAMAT PAGI' : ($zxvHour >= 11 && $zxvHour < 15 ? 'SELAMAT SIANG' : ($zxvHour >= 15 && $zxvHour < 18 ? 'SELAMAT SORE' : 'SELAMAT MALAM'));
    @endphp
    <div id="zxv-welcome-toast" class="zxv-welcome-toast" role="status" aria-live="polite" aria-atomic="true">
        <div class="zxv-welcome-icon" aria-hidden="true">😊</div>
        <div class="zxv-welcome-copy">
            <strong>HALLO {{ Auth::user()->username }} 😊</strong>
            <span>{{ $zxvGreeting }} • SELAMAT DATANG DI PROJECT ZXV PROTECT 👋</span>
        </div>
        <button type="button" class="zxv-welcome-close" aria-label="Tutup notifikasi">×</button>
    </div>
    <!-- ZXV PROTECT:THEME BODY END -->
"""
script = r"""    <!-- ZXV PROTECT:THEME SCRIPT -->
    <script>
    (() => {
        const root = document.body;
        const dashboardPath = /^\/$|^\/dashboard$/;
        const serverPath = /^\/server\//;
        let frame = 0;
        let observerFrame = 0;
        const textOf = (node) => (node?.textContent || '').replace(/\s+/g, ' ').trim();
        const readPercent = (node) => {
            const aria = node?.getAttribute?.('aria-valuenow');
            if (aria !== null && aria !== '' && Number.isFinite(Number(aria))) return Math.max(0, Math.min(100, Number(aria)));
            const style = node?.getAttribute?.('style') || '';
            const match = style.match(/width\s*:\s*([0-9.]+)%/i);
            return match ? Math.max(0, Math.min(100, Number(match[1]))) : 0;
        };
        const classifyCard = (card) => {
            const value = textOf(card);
            card.classList.toggle('zxv-status-online', /\bonline\b/i.test(value));
            card.classList.toggle('zxv-status-offline', /\boffline\b/i.test(value));
            card.classList.toggle('zxv-status-running', /\brunning\b/i.test(value));
        };
        const renderOverview = (cards) => {
            const main = document.querySelector('main');
            if (!main || !root.classList.contains('zxv-dashboard-theme')) return;
            let overview = document.getElementById('zxv-dashboard-overview');
            if (!cards.length) { overview?.remove(); return; }
            if (!overview) {
                overview = document.createElement('section');
                overview.id = 'zxv-dashboard-overview';
                overview.className = 'zxv-dashboard-overview';
                main.prepend(overview);
            }
            const online = cards.filter((card) => card.classList.contains('zxv-status-online') || card.classList.contains('zxv-status-running')).length;
            const offline = Math.max(0, cards.length - online);
            const values = cards.slice(0, 10).map((card) => ({
                name: (textOf(card.querySelector('h2, h3, h4, [class*="font-semibold"], [class*="font-bold"]')) || 'Server').slice(0, 12),
                value: Math.max(Number.parseFloat(card.style.getPropertyValue('--zxv-card-cpu')) || 0, Number.parseFloat(card.style.getPropertyValue('--zxv-card-ram')) || 0),
            }));
            overview.innerHTML = `<div class="zxv-dashboard-overview-head"><div><span class="zxv-overline">OVERVIEW</span><strong>Server Anda</strong><small>Ringkasan dari server yang sedang terlihat.</small></div><div class="zxv-dashboard-stats"><span><i class="is-online"></i>${online} online</span><span><i class="is-offline"></i>${offline} offline</span><span><i class="is-total"></i>${cards.length} server</span></div></div><div class="zxv-bar-chart" aria-label="Grafik resource server">${values.map((item) => `<div class="zxv-bar-item"><div class="zxv-bar-value">${item.value.toFixed(0)}%</div><div class="zxv-bar-track"><span style="height:${Math.max(6, item.value)}%"></span></div><small>${item.name}</small></div>`).join('')}</div>`;
        };
        const markDashboard = () => {
            if (!root.classList.contains('zxv-dashboard-theme')) return;
            const cards = [...document.querySelectorAll('main a[href^="/server/"]')];
            cards.forEach((card) => {
                card.classList.add('zxv-server-card');
                classifyCard(card);
                const bars = [...card.querySelectorAll('[role="progressbar"]')];
                card.style.setProperty('--zxv-card-cpu', `${readPercent(bars[0])}%`);
                card.style.setProperty('--zxv-card-ram', `${readPercent(bars[1])}%`);
                card.style.setProperty('--zxv-card-disk', `${readPercent(bars[2])}%`);
            });
            document.querySelectorAll('main input, main select, main textarea').forEach((el) => el.classList.add('zxv-dashboard-control'));
            renderOverview(cards);
        };
        const syncRoute = () => {
            const path = window.location.pathname.replace(/\/+$/, '') || '/';
            const isDashboard = path === '/' || path === '/dashboard';
            const isServer = serverPath.test(path);
            root.classList.toggle('zxv-server-theme', isServer);
            root.classList.toggle('zxv-dashboard-theme', isDashboard);
            window.cancelAnimationFrame(frame);
            frame = window.requestAnimationFrame(markDashboard);
        };
        ['pushState', 'replaceState'].forEach((method) => {
            const original = history[method];
            history[method] = function () {
                const result = original.apply(this, arguments);
                window.dispatchEvent(new Event('zxv:routechange'));
                return result;
            };
        });
        window.addEventListener('popstate', syncRoute);
        window.addEventListener('zxv:routechange', syncRoute);
        syncRoute();
        const observer = new MutationObserver(() => {
            if (!root.classList.contains('zxv-dashboard-theme')) return;
            window.cancelAnimationFrame(observerFrame);
            observerFrame = window.requestAnimationFrame(markDashboard);
        });
        observer.observe(root, { childList: true, subtree: true });

        const toast = document.getElementById('zxv-welcome-toast');
        if (!toast) return;
        const key = 'zxv-protect-welcome-v3-{{ Auth::id() }}';
        const close = () => { toast.classList.remove('is-visible'); toast.classList.add('is-closing'); window.setTimeout(() => toast.remove(), 260); };
        const show = () => { toast.classList.add('is-visible'); window.setTimeout(close, 6500); };
        toast.querySelector('.zxv-welcome-close')?.addEventListener('click', close);
        try { if (sessionStorage.getItem(key) === '1') return; sessionStorage.setItem(key, '1'); } catch (_) {}
        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', show, { once: true }); else show();
    })();
    </script>
    <!-- ZXV PROTECT:THEME SCRIPT END -->
"""

changed = 0
for raw in sys.argv[1:]:
    path = Path(raw)
    text = path.read_text(encoding='utf-8')
    original = text
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME CSS -->.*?<!-- ZXV PROTECT:THEME CSS END -->\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME BODY -->.*?<!-- ZXV PROTECT:THEME BODY END -->\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME SCRIPT -->.*?<!-- ZXV PROTECT:THEME SCRIPT END -->\s*', '\n', text, flags=re.S)
    text = text.replace('    <link rel="stylesheet" href="{{ asset(\'zxvcode-panel.css\') }}">\n', '')
    text = re.sub(r'\n\s*<div class="zxv-protect-brand".*?</div>\s*', '\n', text, flags=re.S)
    text = re.sub(r'\n\s*<div id="zxv-welcome-toast".*?</div>\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<meta name="theme-color" content="#071225">\s*', '\n', text, flags=re.I)
    text = re.sub(r'\s*<link rel="icon" type="image/svg\+xml" href="\{\{ asset\(\'zxvcode/mark\.svg\'\) \}\}">\s*', '\n', text, flags=re.I)
    if '</head>' in text:
        text = text.replace('</head>', css + '<meta name="theme-color" content="#071225">\n<link rel="icon" type="image/svg+xml" href="{{ asset(\'zxvcode/mark.svg\') }}">\n</head>', 1)
    title_re = re.compile(r'<title>.*?</title>', re.I | re.S)
    if title_re.search(text):
        text = title_re.sub('<title>ZXV PROTECT</title>', text, count=1)
    elif '</head>' in text:
        text = text.replace('</head>', '<title>ZXV PROTECT</title>\n</head>', 1)
    body_pos = text.find('<body')
    if body_pos >= 0:
        body_end = text.find('>', body_pos)
        if body_end >= 0:
            text = text[:body_end+1] + '\n' + body + '\n' + script + text[body_end+1:]
    if text != original:
        path.write_text(text, encoding='utf-8')
        changed += 1
print(f'updated {changed} panel layout(s)')
if changed == 0:
    raise SystemExit('Theme sudah terpasang dan tidak ada perubahan layout yang diperlukan.')
PYTHON

  save_theme_state

  chown www-data:www-data "$panel/$THEME_PATH" 2>/dev/null || true
  chown -R www-data:www-data "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan config:clear >/dev/null 2>&1) || true
  ui_success "Theme ZXV PROTECT selesai dipasang. Dashboard, server list, server workspace, dan tampilan admin ikut diperbarui."
  ui_info 'Sumber theme ada di themes/panel/theme.css dan dipasang ke public/zxvcode-panel.css; komponen React Panel tetap dipakai.'
}

theme_menu() {
  while true; do
    ui_section 'TAMPILAN PANEL'
    printf '  [01] Pasang / update theme\n  [02] Rebuild frontend lalu pasang lagi\n  [03] Hapus theme\n  [04] Backup theme\n  [00] Kembali\n\n'
    read -r -p '  Pilih yang mau dilakukan › ' choice
    case "$choice" in
      1|01) install_theme ;;
      2|02) rebuild_and_apply_theme ;;
      3|03) uninstall_theme ;;
      4|04) backup_theme_files ;;
      0|00) return ;;
      *) ui_warning 'Nomornya belum ada di menu. Coba pilih yang tersedia.' ;;
    esac
  done
}

build_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl tidak ditemukan.'; return 1; }
  cd "$panel"
  ui_info 'Frontend sedang dibangun ulang. Tunggu sebentar, proses ini bisa butuh beberapa menit.'
  if [[ -f package.json ]] && command -v yarn >/dev/null 2>&1; then
    yarn build:production
  elif [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    npm run build:production
  else
    ui_error 'Yarn atau npm tidak ditemukan, jadi frontend belum bisa dibuild ulang.'
    return 1
  fi
  ui_success 'Frontend selesai dibangun ulang.'
}

rebuild_and_apply_theme() {
  if build_theme; then
    ui_info 'Build sudah selesai. Gue pasang ulang theme supaya tampilan terbaru langsung aktif.'
    install_theme
    ui_success 'Rebuild dan penerapan theme selesai.'
  fi
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
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME CSS -->.*?<!-- ZXV PROTECT:THEME CSS END -->\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME BODY -->.*?<!-- ZXV PROTECT:THEME BODY END -->\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<!-- ZXV PROTECT:THEME SCRIPT -->.*?<!-- ZXV PROTECT:THEME SCRIPT END -->\s*', '\n', text, flags=re.S)
    text = text.replace('    <link rel="stylesheet" href="{{ asset(\'zxvcode-panel.css\') }}">\n', '')
    text = re.sub(r'\n\s*<div class="zxv-protect-brand".*?</div>\s*', '\n', text, flags=re.S)
    text = re.sub(r'\n\s*<div id="zxv-welcome-toast".*?</div>\s*', '\n', text, flags=re.S)
    text = re.sub(r'\s*<meta name="theme-color" content="#071225">\s*', '\n', text, flags=re.I)
    text = re.sub(r'\s*<link rel="icon" type="image/svg\+xml" href="\{\{ asset\(\'zxvcode/mark\.svg\'\) \}\}">\s*', '\n', text, flags=re.I)
    text = re.sub(r'<title>\s*ZXV PROTECT\s*</title>', '', text, flags=re.I)
    path.write_text(text, encoding='utf-8')
PYTHON
}

uninstall_theme() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  local baseline="$THEME_BACKUP_ROOT/theme-baseline"
  [[ -d "$panel" ]] || { ui_error 'Folder Panel Pterodactyl tidak ditemukan.'; return 1; }

  local restored=0
  local cleaned=0
  local state="$baseline/state.tsv"
  if [[ -f "$state" ]]; then
    while IFS=$'\t' read -r rel expected; do
      [[ -n "$rel" && -f "$panel/$rel" && -n "$expected" ]] || continue
      current="$(sha256sum "$panel/$rel" | awk '{print $1}')"
      if [[ "$current" == "$expected" && -f "$baseline/${rel#resources/views/}" ]]; then
        :
      fi
    done < "$state"
  fi

  # Restore only files that are still byte-for-byte the themed versions we installed.
  # If Pterodactyl or an admin changed a file after installation, leave that file in place
  # and only remove our own theme markers so we never roll back unrelated Panel updates.
  if [[ -f "$state" ]]; then
    while IFS=$'\t' read -r rel expected; do
      [[ -n "$rel" && -n "$expected" ]] || continue
      current_path="$panel/$rel"
      baseline_path="$baseline/$rel"
      [[ -f "$current_path" && -f "$baseline_path" ]] || continue
      current="$(sha256sum "$current_path" | awk '{print $1}')"
      if [[ "$current" == "$expected" ]]; then
        install -m 0644 "$baseline_path" "$current_path"
        restored=$((restored + 1))
      fi
    done < "$state"
  fi

  remove_theme_markers
  [[ -f "$panel/$THEME_PATH" ]] && rm -f "$panel/$THEME_PATH"
  [[ -f "$panel/public/zxvcode/mark.svg" ]] && rm -f "$panel/public/zxvcode/mark.svg"
  rmdir "$panel/public/zxvcode" 2>/dev/null || true
  (cd "$panel" && php artisan view:clear >/dev/null 2>&1 && php artisan config:clear >/dev/null 2>&1) || true

  if (( restored > 0 )); then
    ui_success "Theme sudah dilepas dan $restored file yang masih persis seperti versi theme dikembalikan."
  else
    ui_success 'Theme sudah dilepas. File Panel yang sudah berubah tidak disentuh, hanya tanda theme yang dibersihkan.'
  fi
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
  ui_success 'Branding ZXV PROTECT sudah diperbarui.'
}
