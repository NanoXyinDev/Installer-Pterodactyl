(() => {
  'use strict';

  const body = document.body;
  if (!body) return;

  const cleanPath = () => window.location.pathname.replace(/\/+$/, '') || '/';
  const isDashboard = () => cleanPath() === '/' || cleanPath() === '/dashboard';
  const isServer = () => /^\/server\//.test(cleanPath());
  const isAdmin = () => /^\/admin(?:\/|$)/.test(cleanPath());
  const isCreateServer = () => /^\/admin\/servers\/new(?:\/|$)/.test(cleanPath());
  const isAdminOverview = () => cleanPath() === '/admin';
  const isGuest = () => /^\/(auth\/)?(login|forgot-password|password\/reset)(?:\/|$)/.test(cleanPath());
  let scheduled = 0;

  const text = (node) => (node?.textContent || '').replace(/\s+/g, ' ').trim();

  const currentUser = () => {
    const user = window.PterodactylUser || {};
    const candidate = user.username || user.name || user.firstName || user.email || '';
    return String(candidate).trim().split('\n')[0].slice(0, 40) || 'kamu';
  };

  const dayGreeting = () => {
    const hour = new Date().getHours();
    if (hour >= 4 && hour < 11) return 'PAGI YANG INDAH';
    if (hour >= 11 && hour < 15) return 'SIANG YANG INDAH';
    if (hour >= 15 && hour < 18) return 'SORE YANG INDAH';
    return 'MALAM YANG INDAH';
  };

  const removeLegacyGreeting = () => {
    const phrases = [
      /HALLO\s+admin/i,
      /SELAMAT DATANG DI PROJECT ZXV PROTECT/i,
    ];
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
    const targets = [];
    let node;
    while ((node = walker.nextNode())) {
      const value = text(node);
      if (!value || value.length > 90) continue;
      if (phrases.some((pattern) => pattern.test(value))) targets.push(node);
    }
    targets.forEach((element) => {
      if (element.id === 'zxv-welcome-toast' || element.closest('#zxv-welcome-toast')) return;
      const value = text(element);
      if (phrases.some((pattern) => pattern.test(value)) && value.length <= 90) element.remove();
    });
  };

  const renameOtherServersToggle = () => {
    if (!isDashboard()) return;
    const walker = document.createTreeWalker(document.querySelector('main') || document.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    let node;
    while ((node = walker.nextNode())) {
      const value = (node.nodeValue || '').replace(/\s+/g, ' ').trim();
      if (/^SHOWING OTHERS?'? SERVER(?:S)?$/i.test(value) || /^SHOWING OTHER'?S SERVER(?:S)?$/i.test(value)) nodes.push(node);
    }
    nodes.forEach((item) => {
      item.nodeValue = ' SHOW ANOTHER SERVER ';
      item.parentElement?.classList.add('zxv-other-server-toggle-label');
    });
  };

  const mountWelcome = () => {
    const welcomeKey = `zxv-welcome:${currentUser()}:${new Date().toISOString().slice(0, 10)}`;

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
          <span></span>
        </div>
        <button class="zxv-welcome-close" type="button" aria-label="Tutup notifikasi">×</button>`;
      document.body.appendChild(toast);

      const close = toast.querySelector('.zxv-welcome-close');
      close?.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopPropagation();
        toast.dataset.dismissed = '1';
        toast.classList.remove('is-visible');
        toast.classList.add('is-closing');
        try { sessionStorage.setItem(`${welcomeKey}:dismissed`, '1'); } catch (_) {}
      });
    }

    const title = toast.querySelector('.zxv-welcome-copy strong');
    const subtitle = toast.querySelector('.zxv-welcome-copy span');
    if (title) title.textContent = `SELAMAT DATANG ${currentUser()}`;
    if (subtitle) subtitle.textContent = `${dayGreeting()} ❤️`;

    let alreadyShown = false;
    try {
      alreadyShown = sessionStorage.getItem(welcomeKey) === '1' ||
        sessionStorage.getItem(`${welcomeKey}:dismissed`) === '1';
    } catch (_) {
      alreadyShown = toast.dataset.shown === '1' || toast.dataset.dismissed === '1';
    }

    if (toast.dataset.dismissed === '1' || alreadyShown) {
      toast.classList.remove('is-visible');
      toast.classList.add('is-closing');
      return;
    }

    toast.dataset.shown = '1';
    try { sessionStorage.setItem(welcomeKey, '1'); } catch (_) {}
    window.setTimeout(() => {
      if (toast.dataset.dismissed !== '1') toast.classList.add('is-visible');
    }, 120);
    window.setTimeout(() => {
      toast.classList.remove('is-visible');
      toast.classList.add('is-closing');
    }, 6800);
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
    body.classList.toggle('zxv-guest-theme', isGuest());
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

  const decorateAdminOverview = () => {
    if (!isAdminOverview()) return;
    const main = document.querySelector('main');
    if (!main || document.getElementById('zxv-admin-overview-brand')) return;
    const brand = document.createElement('section');
    brand.id = 'zxv-admin-overview-brand';
    brand.className = 'zxv-admin-overview-brand';
    brand.innerHTML = `
      <div class="zxv-admin-overview-mark"><img src="/zxvcode/mark.svg" alt="ZXV PROTECT"></div>
      <div class="zxv-admin-overview-brand-copy">
        <span class="zxv-overline">SYSTEM IDENTITY</span>
        <strong>ZXV PROTECT</strong>
        <small>© ${new Date().getFullYear()} ZXV PROTECT · Protected Panel Interface</small>
      </div>
      <span class="zxv-admin-overview-brand-status"><i></i>PROTECTED</span>`;
    const systemInfo = [...main.querySelectorAll('section,div,article')].find((node) => /System Information/i.test(text(node)) && text(node).length < 500);
    (systemInfo?.parentElement || main).prepend(brand);
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

  const decorateCreateServer = () => {
    if (!isCreateServer()) return;

    const main = document.querySelector('main');
    if (!main) return;

    const map = [
      ['#pNodeId', 'zxv-allocation-node'],
      ['#pAllocation', 'zxv-allocation-primary'],
      ['#pAllocationAdditional', 'zxv-allocation-additional'],
      ['#pNestId', 'zxv-create-nest'],
      ['#pEggId', 'zxv-create-egg'],
      ['#pDefaultContainer', 'zxv-create-image'],
    ];
    map.forEach(([selector, className]) => {
      const select = main.querySelector(selector);
      if (!select) return;
      select.classList.add(className);
      const group = select.closest('.form-group');
      if (group) group.classList.add(`zxv-group-${className}`);
      const container = select.nextElementSibling;
      if (container?.classList.contains('select2-container')) container.classList.add(className);
    });

    main.querySelectorAll('.select2-container').forEach((container) => {
      const previous = container.previousElementSibling;
      if (!previous || !previous.matches('select[id]')) return;
      const id = previous.id;
      if (id === 'pNodeId') container.classList.add('zxv-allocation-node');
      if (id === 'pAllocation') container.classList.add('zxv-allocation-primary');
      if (id === 'pAllocationAdditional') container.classList.add('zxv-allocation-additional');
      if (id === 'pNestId') container.classList.add('zxv-create-nest');
      if (id === 'pEggId') container.classList.add('zxv-create-egg');
      if (id === 'pDefaultContainer') container.classList.add('zxv-create-image');
    });

    const allocationBox = main.querySelector('#pNodeId')?.closest('.box');
    if (allocationBox) {
      allocationBox.classList.add('zxv-allocation-box');
      const body = allocationBox.querySelector('.box-body');
      if (body && !body.querySelector('.zxv-allocation-summary')) {
        const summary = document.createElement('div');
        summary.className = 'zxv-allocation-summary';
        summary.innerHTML = '<span class="zxv-allocation-dot"></span><span>Allocation aktif: <strong class="zxv-allocation-value">belum dipilih</strong></span>';
        body.prepend(summary);
      }
      const update = () => {
        const select = main.querySelector('#pAllocation');
        const summary = body?.querySelector('.zxv-allocation-value');
        if (!select || !summary) return;
        const option = select.options[select.selectedIndex];
        const value = option?.textContent?.replace(/\s+/g, ' ').trim() || '';
        summary.textContent = value || 'belum dipilih';
      };
      const select = main.querySelector('#pAllocation');
      if (select && !select.dataset.zxvBound) {
        select.dataset.zxvBound = '1';
        select.addEventListener('change', update);
      }
      update();
    }

    const notes = [
      ['.zxv-group-zxv-allocation-node', 'Pilih node tujuan. Allocation akan mengikuti node yang dipilih.'],
      ['.zxv-group-zxv-allocation-primary', 'Allocation utama menjadi IP:port yang dipakai server saat dibuat.'],
      ['.zxv-group-zxv-allocation-additional', 'Pilih port tambahan bila server membutuhkan lebih dari satu allocation.'],
    ];
    notes.forEach(([selector, message]) => {
      const group = main.querySelector(selector);
      if (!group || group.querySelector('.zxv-create-section-note')) return;
      const note = document.createElement('div');
      note.className = 'zxv-create-section-note';
      note.textContent = message;
      group.appendChild(note);
    });
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
    removeLegacyGreeting();
    renameOtherServersToggle();
    const cards = decorateCards();
    drawOverview(cards);
    decorateAdminOverview();
    decorateAdmin();
    decorateCreateServer();
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
