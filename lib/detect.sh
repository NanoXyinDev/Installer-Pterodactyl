#!/usr/bin/env bash
set -euo pipefail
detect_system(){ OS_NAME="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"; ARCH="$(uname -m)"; HOSTNAME_DETECTED="$(hostname -s 2>/dev/null || hostname)"; PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"; [[ -n $PUBLIC_IP ]] || PUBLIC_IP="$(hostname -I 2>/dev/null|awk '{print $1}')"; export OS_NAME ARCH HOSTNAME_DETECTED PUBLIC_IP; }
