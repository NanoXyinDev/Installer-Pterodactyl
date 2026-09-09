#!/usr/bin/env bash
set -euo pipefail
allocation_menu(){
  while true; do
    ui_section 'ALLOCATION MANAGER'
    printf '  Default Interface : 0.0.0.0 (wildcard)\n  Default Range     : 2000 - 2500\n  Total Ports       : 501\n\n  [01] Validate range\n  [02] Check sample ports\n  [03] Show host addresses\n  [00] Back\n\n'
    read -r -p '  Select › ' a
    case "$a" in
      1)
        local start end
        read -r -p '  Start [2000] › ' start; start="${start:-2000}"
        read -r -p '  End [2500] › ' end; end="${end:-2500}"
        if valid_port "$start" && valid_port "$end" && ((10#$start <= 10#$end)); then
          ui_success "Valid TCP/UDP range: $start-$end."
        else ui_error 'Invalid port range.'; fi;;
      2)
        local p
        for p in 2000 2100 2200 2300 2400 2500; do
          if ss -H -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN; then ui_warning "Port $p busy"; else ui_success "Port $p free"; fi
        done;;
      3) hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d' | sed 's/^/  /';;
      0|00) return;;
      *) ui_warning 'Unknown option.';;
    esac
  done
}
