#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"; source "$BASE_DIR/lib/ui.sh"; source "$BASE_DIR/lib/system.sh"; source "$BASE_DIR/modules/protection.sh"; source "$BASE_DIR/modules/roles.sh"; require_root; install_protection
