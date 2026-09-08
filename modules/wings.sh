#!/usr/bin/env bash
set -euo pipefail
wings_status(){ systemctl is-active --quiet wings 2>/dev/null && echo '● ONLINE' || echo '○ OFFLINE'; }
install_wings(){ require_root; ui_section 'WINGS'; apt_install curl ca-certificates; command -v docker >/dev/null 2>&1 || curl -fsSL https://get.docker.com | sh; mkdir -p /etc/pterodactyl; curl -fL -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64; chmod 0755 /usr/local/bin/wings; cat >/etc/systemd/system/wings.service <<'UNIT'
[Unit]
Description=Pterodactyl Wings
After=docker.service
Requires=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload; systemctl enable wings; if [[ -f /etc/pterodactyl/config.yml ]]; then systemctl restart wings; ui_success "Wings $(wings_status)"; else ui_warning 'Create the node in Pterodactyl and place its generated config.yml at /etc/pterodactyl/config.yml.'; fi; }
