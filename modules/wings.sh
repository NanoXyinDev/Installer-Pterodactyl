#!/usr/bin/env bash
set -euo pipefail
wings_status(){ systemctl is-active --quiet wings 2>/dev/null && echo '● ONLINE' || echo '○ OFFLINE'; }

install_wings(){
  require_root
  require_supported_os
  ui_section 'WINGS'
  apt_install curl ca-certificates
  if ! command -v docker >/dev/null 2>&1; then
    ui_info 'Docker not found; installing Docker Engine.'
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker
  mkdir -p /etc/pterodactyl /var/run/wings
  local arch url tmp
  arch="$(wings_arch)"
  url="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${arch}"
  tmp="$(mktemp)"
  curl -fL --retry 3 -o "$tmp" "$url"
  install -m 0755 "$tmp" /usr/local/bin/wings
  rm -f "$tmp"
  /usr/local/bin/wings --help >/dev/null 2>&1 || { ui_error 'Wings binary validation failed.'; return 1; }
  cat >/etc/systemd/system/wings.service <<'UNIT'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitIntervalSec=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable wings
  if [[ -f /etc/pterodactyl/config.yml ]]; then
    if /usr/local/bin/wings --validate-config 2>/dev/null; then
      systemctl restart wings
      ui_success "Wings $(wings_status)"
    else
      ui_warning 'Wings config validation failed. The existing config.yml was not overwritten.'
      ui_info 'Generate/copy the Node Configuration from Panel > Nodes > your Node > Configuration.'
    fi
  else
    ui_warning 'Wings installed, but /etc/pterodactyl/config.yml is missing.'
    ui_info 'Create the Node in Panel, open its Configuration tab, then paste the generated YAML into /etc/pterodactyl/config.yml.'
  fi
}
