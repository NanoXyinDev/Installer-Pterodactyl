#!/usr/bin/env bash
set -euo pipefail

detect_system(){
  OS_ID="unknown"
  OS_VERSION="unknown"
  OS_NAME="unknown"
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-$OS_ID $OS_VERSION}"
  fi
  ARCH="$(uname -m)"
  HOSTNAME_DETECTED="$(hostname -s 2>/dev/null || hostname)"
  PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  [[ -n "$PUBLIC_IP" ]] || PUBLIC_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  export OS_ID OS_VERSION OS_NAME ARCH HOSTNAME_DETECTED PUBLIC_IP
}

require_supported_os(){
  case "$OS_ID" in
    debian|ubuntu) return 0;;
    *) ui_error "Unsupported OS: $OS_NAME. The automated Panel path supports Debian and Ubuntu."; return 1;;
  esac
}

wings_arch(){
  case "$ARCH" in
    x86_64|amd64) printf '%s\n' amd64;;
    aarch64|arm64) printf '%s\n' arm64;;
    *) ui_error "Unsupported CPU architecture for Wings: $ARCH"; return 1;;
  esac
}
