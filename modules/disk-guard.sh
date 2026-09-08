#!/usr/bin/env bash
set -euo pipefail
volume_path(){ for p in /var/lib/pterodactyl/volumes /var/pterodactyl/volume; do [[ -d $p ]]&& { echo "$p";return; }; done; echo /var/lib/pterodactyl/volumes; }
disk_guard_menu(){ while true; do ui_section 'DISK PROTECTION'; printf '  Limit            10 GB\n  [01] Scan volumes\n  [02] Install safe monitor service\n  [00] Back\n\n'; read -r -p '  Select › ' d; case "$d" in 1)scan_volumes;;2)install_disk_guard;;0|00)return;;*)ui_warning 'Unknown option.';;esac; done; }
scan_volumes(){ local base; base=$(volume_path); [[ -d $base ]]|| { ui_error "Volume path not found: $base";return; }; du -x -BG -d 1 "$base" 2>/dev/null|sort -h|while read -r size path; do [[ $path == "$base" ]]&&continue; local gb=${size%G}; if [[ $gb =~ ^[0-9]+$ ]]&&((gb>10));then ui_warning "$(basename "$path") exceeds 10 GB ($size)";else printf '  %-36s %s\n' "$(basename "$path")" "$size";fi; done; ui_warning 'No automatic rm -rf deletion is enabled. Use Pterodactyl deletion services/API for consistent cleanup.'; }
install_disk_guard(){ ui_warning 'Safe monitor is intentionally non-destructive: it reports oversized volumes instead of deleting them.'; }
