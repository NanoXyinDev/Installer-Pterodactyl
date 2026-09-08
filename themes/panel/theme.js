(() => {
  'use strict';

  const body = document.body;
  if (!body) return;

  const cleanPath = () => window.location.pathname.replace(/\/+$/, '') || '/';
  const isDashboard = () => cleanPath() === '/' || cleanPath() === '/dashboard';
  const isServer = () => /^\/server\//.test(cleanPath());
  const isAdmin = () => /^\/admin(?:\/|$)/.test(cleanPath());
  const isCreateServer = () => /^\/admin\/servers\/new(?:\/|$)/.test(cleanPath());
  let scheduled = 0;

  const text = (node) => (node?.textContent || '').replace(/\s+/g, ' ').trim();

  const currentUser = () => {
    const user = window.PterodactylUser || {};
    const candidate = user.username || user.name || user.firstName || user.email || '';
    return String(candidate).trim().split('\n')[0].slice(0, 40) || 'kamu';
  };

  const mountWelcome = () => {
    if (!isDashboard()) {
      document.getElementById('zxv-welcome-toast')?.remove();
      return;
    }

    let toast = document.getElementById('zxv-welcome-toast');
    if (!toast) {
      toast = document.createElement('aside');
      toast.id = 'zxv-welcome-toast';
      toast.className = 'zxv-welcome-toast';
      toast.innerHTML = `
        <span class="zxv-welcome-icon" aria-hidden="true">❤</span>
        <div class="zxv-welcome-copy">
          <strong></strong>
          <span>MALAM YANG INDAH ❤️</span>
        </div>
        <button class="zxv-welcome-close" type="button" aria-label="Tutup">×</button>`;
      document.body.appendChild(toast);
      toast.querySelector('.zxv-welcome-close')?.addEventListener('click', () => {
        toast.classList.remove('is-visible');
        toast.classList.add('is-closing');
      });
    }

    const title = toast.querySelector('.zxv-welcome-copy strong');
    if (title) title.textContent = `SELAMAT DATANG ${currentUser()}`;
    toast.classList.remove('is-closing');
    if (!toast.dataset.shown) {
      toast.dataset.shown = '1';
      window.setTimeout(() => toast.classList.add('is-visible'), 120);
      window.setTimeout(() => toast.classList.remove('is-visible'), 6800);
    } else if (!toast.classList.contains('is-visible')) {
      toast.classList.add('is-visible');
    }
  };

  const mountMotionLines = () => {
    if (document.getElementById('zxv-motion-lines')) return;
    const layer = document.createElement('div');
    layer.id = 'zxv-motion-lines';
    layer.className = 'zxv-motion-lines';
    layer.setAttribute('aria-hidden', 'true');
    document.body.appendChild(layer);
  };

  const percentFrom = (node) => {
    if (!node) return 0;
    const aria = node.getAttribute('aria-valuenow');
    if (aria !== null && Number.isFinite(Number(aria))) return Math.max(0, Math.min(100, Number(aria)));
    const style = node.getAttribute('style') || '';
    const match = style.match(/(?:width|--value)\s*:\s*([\d.]+)%/i);
    return match ? Math.max(0, Math.min(100, Number(match[1]))) : 0;
  };

  const serverName = (card) => {
    const heading = card.querySelector('h1,h2,h3,h4,h5,[class*="font-semibold"],[class*="font-bold"]');
    return (text(heading) || 'Server').slice(0, 14);
  };

  const setRouteClasses = () => {
    body.classList.add('zxv-motion-enabled');
    body.classList.toggle('zxv-dashboard-theme', isDashboard());
    body.classList.toggle('zxv-server-theme', isServer());
    body.classList.toggle('zxv-admin-theme', isAdmin());
    body.classList.toggle('zxv-server-create-theme', isCreateServer());
  };

  const decorateCards = () => {
    if (!isDashboard()) return [];
    const cards = [...document.querySelectorAll('main a[href^="/server/"]')];
    cards.forEach((card) => {
      card.classList.add('zxv-server-card');
      const value = text(card);
      card.classList.toggle('zxv-status-online', /\bonline\b|\brunning\b/i.test(value));
      card.classList.toggle('zxv-status-offline', /\boffline\b|\bstopped\b/i.test(value));
      const bars = [...card.querySelectorAll('[role="progressbar"]')];
      card.style.setProperty('--zxv-card-cpu', `${percentFrom(bars[0])}%`);
      card.style.setProperty('--zxv-card-ram', `${percentFrom(bars[1])}%`);
      card.style.setProperty('--zxv-card-disk', `${percentFrom(bars[2])}%`);
    });
    document.querySelectorAll('main input, main select, main textarea').forEach((element) => element.classList.add('zxv-dashboard-control'));
    return cards;
  };

  const drawOverview = (cards) => {
    if (!isDashboard()) return;
    const main = document.querySelector('main');
    if (!main) return;
    let panel = document.getElementById('zxv-dashboard-overview');
    if (!cards.length) { panel?.remove(); return; }
    if (!panel) {
      panel = document.createElement('section');
      panel.id = 'zxv-dashboard-overview';
      panel.className = 'zxv-dashboard-overview';
      main.prepend(panel);
    }
    const online = cards.filter((card) => card.classList.contains('zxv-status-online')).length;
    const offline = Math.max(0, cards.length - online);
    const values = cards.slice(0, 12).map((card) => {
      const cpu = Number.parseFloat(card.style.getPropertyValue('--zxv-card-cpu')) || 0;
      const ram = Number.parseFloat(card.style.getPropertyValue('--zxv-card-ram')) || 0;
      const disk = Number.parseFloat(card.style.getPropertyValue('--zxv-card-disk')) || 0;
      return { name: serverName(card), value: Math.max(cpu, ram, disk) };
    });
    const markup = `
      <div class="zxv-dashboard-overview-head">
        <div><span class="zxv-overline">RINGKASAN</span><strong>Server kamu</strong><small>Resource mengikuti data yang sedang tampil di dashboard.</small></div>
        <div class="zxv-dashboard-stats"><span><i class="is-online"></i>${online} online</span><span><i class="is-offline"></i>${offline} offline</span><span><i class="is-total"></i>${cards.length} server</span></div>
      </div>
      <div class="zxv-bar-chart" aria-label="Grafik penggunaan resource server">
        ${values.map((item) => `<div class="zxv-bar-item"><div class="zxv-bar-value">${item.value.toFixed(0)}%</div><div class="zxv-bar-track"><span style="height:${Math.max(6, Math.min(100, item.value))}%"></span></div><small>${item.name}</small></div>`).join('')}
      </div>`;
    if (panel.innerHTML !== markup) panel.innerHTML = markup;
  };

  const decorateAdmin = () => {
    if (!isAdmin()) return;

    document.querySelectorAll('main input, main select, main textarea').forEach((element) => element.classList.add('zxv-admin-control'));
    document.querySelectorAll('main button, main a[role="button"]').forEach((element) => element.classList.add('zxv-admin-button'));

    const apiLink = [...document.querySelectorAll('a,button')].find((node) => /application api|api documentation|documentation|api credentials/i.test(text(node)));
    if (apiLink && !document.getElementById('zxv-official-badge')) {
      const host = apiLink.closest('li,div,section,nav') || apiLink.parentElement;
      if (host) {
        const badge = document.createElement('span');
        badge.id = 'zxv-official-badge';
        badge.className = 'zxv-official-badge';
        badge.innerHTML = '<span class="zxv-official-dot"></span><span>ZXV OFFICIAL</span><small>Panel UI</small>';
        host.appendChild(badge);
      }
    }

    if (isCreateServer()) {
      const main = document.querySelector('main');
      if (main && !document.getElementById('zxv-create-banner')) {
        const banner = document.createElement('div');
        banner.id = 'zxv-create-banner';
        banner.className = 'zxv-create-banner';
        banner.innerHTML = '<div><span class="zxv-overline">SERVER SETUP</span><strong>Buat server dengan tampilan yang lebih rapi.</strong><small>Field, pilihan resource, allocation, egg, dan tombol aksi tetap mengikuti Panel bawaan.</small></div><span class="zxv-create-chip">ZXV PROTECT</span>';
        main.prepend(banner);
      }
    }
  };

  const notify = (message) => {
    if (!isAdmin() && !isDashboard() && !isServer()) return;
    let box = document.getElementById('zxv-live-notice');
    if (!box) {
      box = document.createElement('div');
      box.id = 'zxv-live-notice';
      box.className = 'zxv-live-notice';
      document.body.appendChild(box);
    }
    box.innerHTML = `<span class="zxv-notice-dot"></span><div><strong>ZXV PROTECT</strong><small>${message}</small></div>`;
    box.classList.add('is-visible');
    window.clearTimeout(box._hideTimer);
    box._hideTimer = window.setTimeout(() => box.classList.remove('is-visible'), 2600);
  };

  const refresh = () => {
    mountMotionLines();
    setRouteClasses();
    const cards = decorateCards();
    drawOverview(cards);
    decorateAdmin();
    mountWelcome();
  };

  const scheduleRefresh = () => {
    window.cancelAnimationFrame(scheduled);
    scheduled = window.requestAnimationFrame(refresh);
  };

  ['pushState', 'replaceState'].forEach((method) => {
    const original = history[method];
    history[method] = function (...args) {
      const result = original.apply(this, args);
      window.dispatchEvent(new Event('zxv:routechange'));
      return result;
    };
  });

  window.addEventListener('popstate', scheduleRefresh);
  window.addEventListener('zxv:routechange', () => { scheduleRefresh(); notify('Tampilan sudah diperbarui.'); });
  window.addEventListener('resize', scheduleRefresh, { passive: true });

  const observer = new MutationObserver(scheduleRefresh);
  observer.observe(body, { childList: true, subtree: true });

  refresh();
})();
