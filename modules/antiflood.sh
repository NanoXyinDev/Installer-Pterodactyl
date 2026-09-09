#!/usr/bin/env bash
set -euo pipefail

ZXV_AF_DIR=/etc/zxvcode/antiflood
ZXV_AF_BLOCKLIST="$ZXV_AF_DIR/permanent-ips.txt"
ZXV_AF_ALLOWLIST="$ZXV_AF_DIR/allowlist.txt"
ZXV_AF_SCRIPT=/usr/local/sbin/zxvcode-antiflood
ZXV_AF_UNIT=/etc/systemd/system/zxvcode-antiflood.service
ZXV_AF_NFT=/etc/nftables.d/zxvcode-antiflood.nft
ZXV_AF_NGINX=/etc/nginx/conf.d/zxvcode-antiflood.conf

antiflood_install(){
  require_root
  mkdir -p "$ZXV_AF_DIR" /etc/nftables.d
  touch "$ZXV_AF_BLOCKLIST" "$ZXV_AF_ALLOWLIST"
  chmod 0644 "$ZXV_AF_BLOCKLIST" "$ZXV_AF_ALLOWLIST"
  cat > "$ZXV_AF_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR=/etc/zxvcode/antiflood
BLOCK="$DIR/permanent-ips.txt"
ALLOW="$DIR/allowlist.txt"
NGINX_LOG=/var/log/nginx/access.log

auto_block(){
  local ip="$1"
  [[ -n "$ip" ]] || return 0
  grep -Eq '^(127\\.|10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|::1$|fc|fd)' <<< "$ip" && return 0
  grep -Fqx "$ip" "$ALLOW" 2>/dev/null && return 0
  grep -Fqx "$ip" "$BLOCK" 2>/dev/null && return 0
  printf '%s\n' "$ip" >> "$BLOCK"
  nft add element inet zxvcode_antiflood blocked4 "{ $ip }" 2>/dev/null || true
  logger -t zxvcode-antiflood "PERMANENT BLOCK $ip"
}

l4_scan(){
  command -v ss >/dev/null 2>&1 || return 0
  ss -Htan state syn-recv 2>/dev/null | awk '{print $5}' | sed -E 's/.*[^0-9]([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+):[0-9]+$/\\1/' | sort | uniq -c |
  while read -r count ip; do
    [[ "$count" =~ ^[0-9]+$ ]] || continue
    if (( count >= 80 )); then auto_block "$ip"; fi
  done
}

l7_scan(){
  [[ -r "$NGINX_LOG" ]] || return 0
  tail -n 5000 "$NGINX_LOG" 2>/dev/null |
    awk '{print $1}' | grep -E '^[0-9a-fA-F:.]+$' | sort | uniq -c |
  while read -r count ip; do
    [[ "$count" =~ ^[0-9]+$ ]] || continue
    if (( count >= 350 )); then auto_block "$ip"; fi
  done
}

while :; do
  l4_scan || true
  l7_scan || true
  sleep 5
done
SCRIPT
  chmod 0755 "$ZXV_AF_SCRIPT"

  cat > "$ZXV_AF_NFT" <<'NFT'
table inet zxvcode_antiflood {
  set blocked4 { type ipv4_addr; flags interval; }
  chain input {
    type filter hook input priority -100; policy accept;
    ip saddr @blocked4 drop
  }
}
NFT

  cat > "$ZXV_AF_UNIT" <<'UNIT'
[Unit]
Description=ZXVCode Anti Flood Guard
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/zxvcode-antiflood
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/zxvcode/antiflood /var/log

[Install]
WantedBy=multi-user.target
UNIT

  cat > "$ZXV_AF_NGINX" <<'NGINX'
limit_req_zone $binary_remote_addr zone=zxv_l7:20m rate=20r/s;
limit_conn_zone $binary_remote_addr zone=zxv_conn:20m;
NGINX

  if command -v nft >/dev/null 2>&1; then
    nft add table inet zxvcode_antiflood 2>/dev/null || true
    nft 'add set inet zxvcode_antiflood blocked4 { type ipv4_addr; flags interval; }' 2>/dev/null || true
    nft 'add chain inet zxvcode_antiflood input { type filter hook input priority -100; policy accept; }' 2>/dev/null || true
    nft 'add rule inet zxvcode_antiflood input ip saddr @blocked4 drop' 2>/dev/null || true
    while IFS= read -r ip; do
      [[ -n "$ip" ]] || continue
      nft add element inet zxvcode_antiflood blocked4 "{ $ip }" 2>/dev/null || true
    done < "$ZXV_AF_BLOCKLIST"
  else
    ui_warning 'nftables belum ada di server ini, jadi pemblokiran IP otomatis belum bisa jalan.'
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable --now zxvcode-antiflood.service
  fi
  if command -v nginx >/dev/null 2>&1; then
    nginx -t >/dev/null 2>&1 || ui_warning 'Nginx config existing gagal test; limit zone file ditulis tetapi tidak dipaksa reload.'
  fi
  ui_success 'Anti FLOOD sudah aktif. Trafik koneksi dan request yang terlalu ramai sekarang ikut dipantau.'
  ui_warning 'IP yang terdeteksi flood akan diblokir permanen. Masukkan IP orang tepercaya ke allowlist supaya tidak ikut terblokir.'
}

antiflood_status(){
  ui_section 'STATUS ANTI FLOOD'
  if systemctl is-active --quiet zxvcode-antiflood.service; then ui_success 'Penjaga trafik: aktif'; else ui_error 'Penjaga trafik: tidak aktif'; fi
  printf '  Permanent blocks : %s\n' "$(grep -cve '^\s*$' "$ZXV_AF_BLOCKLIST" 2>/dev/null || true)"
  printf '  Allowlist        : %s\n' "$(grep -cve '^\s*$' "$ZXV_AF_ALLOWLIST" 2>/dev/null || true)"
  printf '  Block database    : %s\n' "$ZXV_AF_BLOCKLIST"
}

antiflood_add_allow(){
  local ip="$1"
  [[ "$ip" =~ ^[0-9a-fA-F:.]+$ ]] || { ui_error 'Format IP-nya kelihatannya belum benar.'; return 1; }
  grep -Fqx "$ip" "$ZXV_AF_ALLOWLIST" 2>/dev/null || printf '%s\n' "$ip" >> "$ZXV_AF_ALLOWLIST"
  ui_success "IP $ip sudah masuk daftar aman."
}

antiflood_unblock(){
  local ip="$1" tmp
  tmp="$(mktemp)"
  grep -Fvx "$ip" "$ZXV_AF_BLOCKLIST" > "$tmp" || true
  mv "$tmp" "$ZXV_AF_BLOCKLIST"
  nft delete element inet zxvcode_antiflood blocked4 "{ $ip }" 2>/dev/null || true
  ui_success "IP $ip sudah dikeluarkan dari blokir permanen."
}

antiflood_menu(){
  while true; do
    ui_section 'ANTI FLOOD / PENJAGA DDOS'
    printf '  [01] Aktifkan Anti FLOOD\n  [02] Status\n  [03] Tambahkan IP tepercaya\n  [04] Buka blokir IP\n  [05] Lihat IP yang diblokir permanen\n  [00] Back\n\n'
    read -r -p '  Select › ' p
    case "$p" in
      1) antiflood_install;;
      2) antiflood_status;;
      3) read -r -p '  IP › ' ip; antiflood_add_allow "$ip";;
      4) read -r -p '  IP › ' ip; antiflood_unblock "$ip";;
      5) cat "$ZXV_AF_BLOCKLIST" 2>/dev/null | sed 's/^/  /' || true;;
      0|00) return;;
      *) ui_warning 'Pilihan itu belum tersedia.';;
    esac
  done
}
