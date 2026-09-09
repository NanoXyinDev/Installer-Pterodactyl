#!/usr/bin/env bash
set -euo pipefail
R=$'\033[0m'; C=$'\033[38;5;81m'; B=$'\033[38;5;69m'; G=$'\033[38;5;78m'; Y=$'\033[38;5;221m'; E=$'\033[38;5;203m'; D=$'\033[2m'; W=$'\033[97m'
ui_header(){ printf '%b\n' "${C}╭──────────────────────────────────────────────────────────╮${R}" "${C}│${R}  ${W}ZxvCode${R} / ${B}PTERODACTYL INSTALLER${R}                 ${C}│${R}" "${C}│${R}  ${D}Panel setup • tampilan • keamanan${R} ${C}│${R}" "${C}╰──────────────────────────────────────────────────────────╯${R}"; }
ui_success(){ printf '  %b %s\n' "${G}✓${R}" "$*"; }
ui_info(){ printf '  %b %s\n' "${C}›${R}" "$*"; }
ui_warning(){ printf '  %b %s\n' "${Y}!${R}" "$*"; }
ui_error(){ printf '  %b %s\n' "${E}✗${R}" "$*"; }
ui_farewell(){
  printf '\n'
  printf '%b\n' "${C}╭──────────────────────────────────────────────────────────╮${R}"
  printf '%b\n' "${C}│${R}  ${W}UPDATE ZXVCODE SUDAH SELESAI${R}                            ${C}│${R}"
  printf '%b\n' "${C}│${R}  ${D}Makasih sudah pakai ZxvCode. Semoga panelnya lancar dan nyaman dipakai.${R}          ${C}│${R}"
  printf '%b\n' "${C}│${R}  ${G}Semua sudah siap. Sampai ketemu lagi!${R}   ${C}│${R}"
  printf '%b\n' "${C}╰──────────────────────────────────────────────────────────╯${R}"
  printf '\n'
}
ui_section(){ printf '\n  %b\n  %b\n' "${W}$*${R}" "${D}────────────────────────────────────────────────────────${R}"; }
require_root(){ [[ ${EUID:-0} -eq 0 ]] || { ui_error 'Jalankan installer sebagai root ya.'; exit 1; }; }
ui_dashboard(){ ui_header; printf '\n  %b\n' "${D}KONDISI SERVER${R}"; printf '  OS           %s\n' "${OS_NAME:-unknown}"; printf '  ARCH         %s\n' "${ARCH:-unknown}"; printf '  PUBLIC IP    %s\n' "${PUBLIC_IP:-unknown}"; printf '  HOSTNAME     %s\n' "${HOSTNAME_DETECTED:-unknown}"; printf '  PANEL        %s\n' "$(panel_status)"; printf '  WINGS        %s\n' "$(wings_status)"; ui_section 'MENU UTAMA'; }
progress(){ local label=$1 i; for i in 0 20 40 60 80 100; do printf '\r  %-24s [' "$label"; printf '%*s' $((i/5)) ''|tr ' ' '█'; printf '%*s' $(((100-i)/5)) ''|tr ' ' '░'; printf '] %3d%%' "$i"; sleep .06; done; printf '\n'; }
ui_step(){ printf '\n  %b %s\n' "${C}◆${R}" "$*"; }
ui_step_ok(){ printf '  %b %s\n' "${G}✓${R}" "$*"; }
ui_step_fail(){ printf '  %b %s\n' "${E}✗${R}" "$*"; }
ui_run(){
  local label="$1"; shift
  local log rc start now elapsed spin='|/-\'
  local tmp="${TMPDIR:-/tmp}/zxvcode-step.$$.log"
  : > "$tmp"
  start="$(date +%s)"
  "$@" >"$tmp" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    now="$(date +%s)"; elapsed=$((now-start))
    printf '\r  %b %-38s %s %02ds' "${C}›${R}" "$label" "${spin:0:1}" "$elapsed"
    spin="${spin:1}${spin:0:1}"
    sleep 0.2
  done
  wait "$pid"; rc=$?
  printf '\r\033[2K'
  if (( rc == 0 )); then
    ui_step_ok "$label"
    rm -f "$tmp"
    return 0
  fi
  ui_step_fail "$label"
  printf '  %b Output terakhir:\n' "${Y}!${R}"
  tail -n 18 "$tmp" | sed 's/^/    /'
  rm -f "$tmp"
  return "$rc"
}
ui_progress_steps(){
  local current="$1" total="$2" label="$3"
  local width=28 filled
  (( total > 0 )) || total=1
  filled=$(( current * width / total ))
  printf '\r  %b %-30s [' "${C}›${R}" "$label"
  printf '%*s' "$filled" '' | tr ' ' '█'
  printf '%*s' $((width-filled)) '' | tr ' ' '░'
  printf '] %d/%d' "$current" "$total"
}
