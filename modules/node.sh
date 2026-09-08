#!/usr/bin/env bash
set -euo pipefail
node_menu(){
  while true; do
    ui_section 'NODE & LOCATION WIZARD'
    printf '  [01] Interactive Node profile\n  [02] Create Location via Artisan\n  [03] Show saved Node profile\n  [04] Install/repair Wings\n  [00] Back\n\n'
    read -r -p '  Select › ' n
    case "$n" in
      1) node_profile;;
      2) create_location;;
      3) show_node;;
      4) install_wings;;
      0|00) return;;
      *) ui_warning 'Unknown option.';;
    esac
  done
}
node_profile(){
  ui_section 'NODE CONFIGURATION'
  read -r -p '  Node Name [NODE-01] › ' NODE_NAME
  NODE_NAME="${NODE_NAME:-NODE-01}"
  read -r -p '  Node Description [NODE BY ZXVCODE] › ' NODE_DESCRIPTION
  NODE_DESCRIPTION="${NODE_DESCRIPTION:-NODE BY ZXVCODE}"
  read -r -p '  Location Name [Jakarta] › ' NODE_LOCATION
  NODE_LOCATION="${NODE_LOCATION:-Jakarta}"
  read -r -p '  Node FQDN › ' NODE_FQDN
  [[ -n "$NODE_FQDN" ]] || { ui_error 'Node FQDN is required.'; return; }
  read -r -p '  SSL [y/N] › ' NODE_SSL
  NODE_SSL="${NODE_SSL:-n}"; NODE_SSL="${NODE_SSL,,}"
  read -r -p '  Behind Proxy [y/N] › ' NODE_PROXY
  NODE_PROXY="${NODE_PROXY:-n}"; NODE_PROXY="${NODE_PROXY,,}"
  read -r -p '  Total Memory (MB) › ' NODE_RAM
  read -r -p '  Memory Overallocate (%) [0] › ' NODE_RAM_OVER
  NODE_RAM_OVER="${NODE_RAM_OVER:-0}"
  read -r -p '  Total Disk (MB) › ' NODE_DISK
  read -r -p '  Disk Overallocate (%) [0] › ' NODE_DISK_OVER
  NODE_DISK_OVER="${NODE_DISK_OVER:-0}"
  read -r -p '  Daemon Port [8080] › ' NODE_DAEMON_PORT
  NODE_DAEMON_PORT="${NODE_DAEMON_PORT:-8080}"
  read -r -p '  SFTP Port [2022] › ' NODE_SFTP_PORT
  NODE_SFTP_PORT="${NODE_SFTP_PORT:-2022}"
  read -r -p '  Allocation IP [0.0.0.0] › ' NODE_ALLOC_IP
  NODE_ALLOC_IP="${NODE_ALLOC_IP:-0.0.0.0}"
  read -r -p '  Allocation Start [2000] › ' NODE_ALLOC_START
  NODE_ALLOC_START="${NODE_ALLOC_START:-2000}"
  read -r -p '  Allocation End [2500] › ' NODE_ALLOC_END
  NODE_ALLOC_END="${NODE_ALLOC_END:-2500}"
  mkdir -p /etc/pterodactyl
  cat >/etc/pterodactyl/zxvcode-node-profile.conf <<EOF
NODE_NAME=$(printf '%q' "$NODE_NAME")
NODE_DESCRIPTION=$(printf '%q' "$NODE_DESCRIPTION")
NODE_LOCATION=$(printf '%q' "$NODE_LOCATION")
NODE_FQDN=$(printf '%q' "$NODE_FQDN")
NODE_SSL=$(printf '%q' "$NODE_SSL")
NODE_PROXY=$(printf '%q' "$NODE_PROXY")
NODE_RAM=$(printf '%q' "$NODE_RAM")
NODE_RAM_OVER=$(printf '%q' "$NODE_RAM_OVER")
NODE_DISK=$(printf '%q' "$NODE_DISK")
NODE_DISK_OVER=$(printf '%q' "$NODE_DISK_OVER")
NODE_DAEMON_PORT=$(printf '%q' "$NODE_DAEMON_PORT")
NODE_SFTP_PORT=$(printf '%q' "$NODE_SFTP_PORT")
NODE_ALLOC_IP=$(printf '%q' "$NODE_ALLOC_IP")
NODE_ALLOC_START=$(printf '%q' "$NODE_ALLOC_START")
NODE_ALLOC_END=$(printf '%q' "$NODE_ALLOC_END")
EOF
  chmod 0600 /etc/pterodactyl/zxvcode-node-profile.conf
  ui_success 'Node profile saved to /etc/pterodactyl/zxvcode-node-profile.conf.'
  ui_info 'Pterodactyl generates the authoritative Wings config.yml from the Node Configuration page.'
}
create_location(){
  [[ -f "${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}/artisan" ]] || { ui_error 'Install Panel first.'; return; }
  local short long
  read -r -p '  Location short code [id1] › ' short
  short="${short:-id1}"
  read -r -p '  Location description › ' long
  long="${long:-ZxvCode Node Location}"
  (cd "${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}" && php artisan p:location:make --short="$short" --long="$long")
  ui_success "Location $short created."
}
show_node(){
  if [[ -f /etc/pterodactyl/zxvcode-node-profile.conf ]]; then
    ui_section 'SAVED NODE PROFILE'
    cat /etc/pterodactyl/zxvcode-node-profile.conf
  else
    ui_warning 'No saved Node profile.'
  fi
}
