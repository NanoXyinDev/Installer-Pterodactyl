#!/usr/bin/env bash
set -euo pipefail
apt_install(){ export DEBIAN_FRONTEND=noninteractive; apt-get update -y; apt-get install -y "$@"; }
backup_file(){
  local f="$1" out
  [[ -f "$f" ]] || return 0
  mkdir -p /var/backups/zxvcode-ptero
  out="/var/backups/zxvcode-ptero/$(basename "$f").$(date +%Y%m%d-%H%M%S).bak"
  cp -a -- "$f" "$out"
  printf '%s\n' "$out"
}
valid_uint(){ [[ "$1" =~ ^[0-9]+$ ]]; }
valid_port(){ valid_uint "$1" && ((10#$1 >= 1 && 10#$1 <= 65535)); }
valid_percent(){ valid_uint "$1" && ((10#$1 >= 0 && 10#$1 <= 100)); }
valid_ip_or_host(){ [[ "$1" =~ ^[A-Za-z0-9_.:-]+$ ]]; }
