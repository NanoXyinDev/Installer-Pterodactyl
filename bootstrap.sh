#!/usr/bin/env bash
set -euo pipefail
umask 022
REPO_ARCHIVE_URL="https://github.com/NanoXyinDev/Installer-Pterodactyl-v1/archive/refs/heads/main.tar.gz"
command -v curl >/dev/null 2>&1 || { printf 'curl is required.\n' >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { printf 'tar is required.\n' >&2; exit 1; }
TMP_DIR="$(mktemp -d /tmp/zxvcode-ptero.XXXXXX)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM
ARCHIVE="$TMP_DIR/project.tar.gz"
curl -fsSL --retry 3 --retry-delay 1 "$REPO_ARCHIVE_URL" -o "$ARCHIVE"
tar -tzf "$ARCHIVE" >/dev/null
tar -xzf "$ARCHIVE" -C "$TMP_DIR"
ROOT_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'Installer-Pterodactyl-v1-*' -print -quit)"
[[ -n "$ROOT_DIR" ]] || { printf 'Installer archive root not found.\n' >&2; exit 1; }
[[ -f "$ROOT_DIR/install.sh" && -f "$ROOT_DIR/config/defaults.conf" ]] || { printf 'Installer archive is incomplete.\n' >&2; exit 1; }
exec bash "$ROOT_DIR/install.sh" "$@"
