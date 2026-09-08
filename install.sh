#!/usr/bin/env bash
set -euo pipefail
ACCESS_KEY="ZxvHost"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)"
source "$BASE_DIR/lib/ui.sh"; source "$BASE_DIR/lib/detect.sh"; source "$BASE_DIR/lib/system.sh"; source "$BASE_DIR/lib/panel.sh"; source "$BASE_DIR/modules/wings.sh"; source "$BASE_DIR/modules/node.sh"; source "$BASE_DIR/modules/allocation.sh"; source "$BASE_DIR/modules/theme.sh"; source "$BASE_DIR/modules/protection.sh"; source "$BASE_DIR/modules/disk-guard.sh"
require_root; clear; ui_header; printf '\n  Access key required.\n\n'; read -r -s -p '  Key › ' entered; printf '\n'; [[ $entered == "$ACCESS_KEY" ]]|| { ui_error 'Invalid access key.';exit 1; }; ui_success 'Access granted.'; detect_system
while true; do ui_dashboard; printf '\n  [01] Install Pterodactyl Panel\n  [02] Install Wings\n  [03] Node & Location Manager\n  [04] Allocation Manager\n  [05] Theme Studio\n  [06] Protection Manager\n  [07] Disk Protection\n  [08] Panel Maintenance\n  [09] Uninstall Panel\n  [00] Exit\n\n'; read -r -p '  Select option › ' opt; case "$opt" in 1)install_panel;;2)install_wings;;3)node_menu;;4)allocation_menu;;5)theme_menu;;6)protection_menu;;7)disk_guard_menu;;8)panel_maintenance;;9)"$BASE_DIR/uninstallpanel.sh";;0|00)exit 0;;*)ui_warning 'Unknown option.';;esac; printf '\n  Press Enter to continue...';read -r;done
