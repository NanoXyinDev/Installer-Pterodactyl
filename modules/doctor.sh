#!/usr/bin/env bash
set -euo pipefail

health_check() {
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}" ok=0 warn=0
  ui_section 'SYSTEM HEALTH'
  check() {
    local label="$1" cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then ui_success "$label"; ok=$((ok+1)); else ui_warning "$label"; warn=$((warn+1)); fi
  }
  check 'PHP 8.2+ available' 'php -r "exit(version_compare(PHP_VERSION, \"8.2.0\", \">=\") ? 0 : 1);"'
  check 'Composer 2 available' 'composer --version 2>/dev/null | grep -q "Composer version 2"'
  check 'MariaDB reachable' 'systemctl is-active --quiet mariadb'
  check 'Redis reachable' 'systemctl is-active --quiet redis-server || systemctl is-active --quiet redis'
  check 'Nginx configuration valid' 'nginx -t'
  check 'Docker available' 'docker info'
  check 'Wings binary available' 'test -x /usr/local/bin/wings'
  check 'Wings service active' 'systemctl is-active --quiet wings'
  if [[ -f "$panel/artisan" ]]; then
    check 'Panel application responds to Artisan' '(cd "$panel" && php artisan about)'
    check 'Panel storage writable' 'test -w "$panel/storage" && test -w "$panel/bootstrap/cache"'
  else
    ui_info 'Panel is not installed; Panel-specific checks were skipped.'
  fi
  printf '\n  Result: %s passed, %s warnings.\n' "$ok" "$warn"
  (( warn == 0 )) || return 1
}

service_logs() {
  local service
  read -r -p '  Service [wings/pteroq/nginx/mariadb/redis] › ' service
  case "$service" in
    wings|pteroq|nginx|mariadb|redis|redis-server)
      journalctl -u "$service" -n 80 --no-pager || true;;
    *) ui_error 'Unsupported service name.'; return 1;;
  esac
}

doctor_menu() {
  while true; do
    ui_section 'SYSTEM HEALTH & DIAGNOSTICS'
    printf '  [01] Run health check\n  [02] Show service status\n  [03] View recent service logs\n  [00] Back\n\n'
    read -r -p '  Select › ' choice
    case "$choice" in
      1|01) health_check || true;;
      2|02) systemctl --no-pager --type=service --state=running | grep -E 'nginx|mariadb|redis|docker|wings|pteroq' || true;;
      3|03) service_logs;;
      0|00) return;;
      *) ui_warning 'Unknown option.';;
    esac
  done
}
