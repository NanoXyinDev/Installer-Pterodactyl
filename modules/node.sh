#!/usr/bin/env bash
set -euo pipefail
node_menu(){ while true; do ui_section 'NODE & LOCATION MANAGER'; printf '  [01] Auto metadata\n  [02] Show metadata\n  [03] Wings status\n  [00] Back\n\n'; read -r -p '  Select › ' n; case "$n" in 1) auto_node;;2) show_node;;3) printf '  %s\n' "$(wings_status)";;0|00)return;;*)ui_warning 'Unknown option.';;esac; done; }
auto_node(){ printf '\n  Location     AUTO-%s\n  Node         NODE-%s\n  Description  NODE BY ZXVCODE\n  FQDN         %s\n' "${PUBLIC_IP:-NODE}" "${HOSTNAME_DETECTED:-01}" "${PUBLIC_IP:-auto}"; ui_warning 'Remote node creation requires a Panel Application API credential; this build does not hard-code credentials.'; }
show_node(){ auto_node; }
