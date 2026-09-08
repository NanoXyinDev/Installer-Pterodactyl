#!/usr/bin/env bash
set -euo pipefail
R=$'\033[0m'; C=$'\033[38;5;81m'; B=$'\033[38;5;69m'; G=$'\033[38;5;78m'; Y=$'\033[38;5;221m'; E=$'\033[38;5;203m'; D=$'\033[2m'; W=$'\033[97m'
ui_header(){ printf '%b\n' "${C}╭──────────────────────────────────────────────────────────╮${R}" "${C}│${R}  ${W}ZxvCode${R} / ${B}PTERODACTYL INSTALLER${R}                 ${C}│${R}" "${C}│${R}  ${D}Panel automation • Theme Studio • Protection Engine${R} ${C}│${R}" "${C}╰──────────────────────────────────────────────────────────╯${R}"; }
ui_success(){ printf '  %b %s\n' "${G}✓${R}" "$*"; }
ui_info(){ printf '  %b %s\n' "${C}›${R}" "$*"; }
ui_warning(){ printf '  %b %s\n' "${Y}!${R}" "$*"; }
ui_error(){ printf '  %b %s\n' "${E}✗${R}" "$*"; }
ui_section(){ printf '\n  %b\n  %b\n' "${W}$*${R}" "${D}────────────────────────────────────────────────────────${R}"; }
require_root(){ [[ ${EUID:-0} -eq 0 ]] || { ui_error 'Run as root.'; exit 1; }; }
ui_dashboard(){ ui_header; printf '\n  %b\n' "${D}SYSTEM${R}"; printf '  OS           %s\n' "${OS_NAME:-unknown}"; printf '  ARCH         %s\n' "${ARCH:-unknown}"; printf '  PUBLIC IP    %s\n' "${PUBLIC_IP:-unknown}"; printf '  HOSTNAME     %s\n' "${HOSTNAME_DETECTED:-unknown}"; printf '  PANEL        %s\n' "$(panel_status)"; printf '  WINGS        %s\n' "$(wings_status)"; ui_section 'MAIN MENU'; }
progress(){ local label=$1 i; for i in 0 20 40 60 80 100; do printf '\r  %-24s [' "$label"; printf '%*s' $((i/5)) ''|tr ' ' '█'; printf '%*s' $(((100-i)/5)) ''|tr ' ' '░'; printf '] %3d%%' "$i"; sleep .06; done; printf '\n'; }
