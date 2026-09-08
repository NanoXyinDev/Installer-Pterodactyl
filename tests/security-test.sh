#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL: %s\n' "$1"; exit 1; }
ok(){ printf 'PASS: %s\n' "$1"; }

command -v php >/dev/null 2>&1 || fail 'php is required for payload syntax tests'

count=0
while IFS=$'\t' read -r id name dest rel sha; do
  [[ -n "$id" ]] || continue
  count=$((count+1))
  file="$ROOT/protect/$rel"
  [[ -f "$file" ]] || fail "missing payload $rel"
  [[ -n "$sha" && "$sha" != "-" ]] || fail "missing checksum for $rel"
  actual="$(sha256sum -- "$file" | awk '{print $1}')"
  [[ "$actual" == "$sha" ]] || fail "checksum mismatch $rel"
  if [[ "$file" == *.php ]]; then
    php -l "$file" >/dev/null || fail "PHP syntax error $rel"
  fi
done < "$ROOT/protect/manifest.tsv"
[[ "$count" -eq 23 ]] || fail "expected 23 manifest entries, found $count"
ok 'manifest count + checksums + PHP syntax'

handler_count="$(cut -f2 "$ROOT/protect/source-index.tsv" | sed -E 's/^(PROTECT[0-9]+).*/\1/' | sort -u | wc -l | tr -d ' ')"
[[ "$handler_count" -eq 14 ]] || fail "expected 14 named protection handlers, found $handler_count"
! grep -q '^PROTECT15' "$ROOT/protect/source-index.tsv" || fail 'unexpected PROTECT15 handler present'
ok 'PROTECT1–PROTECT14 source mapping; no fabricated PROTECT15'

user_controller="$ROOT/protect/payloads/11-UserController.php"
grep -q 'public function view(User \$user): View' "$user_controller" || fail 'UserController::view missing'
grep -q 'authUser->id !== 1 && \$authUser->id !== \$user->id' "$user_controller" || fail 'UserController::view IDOR guard missing'
ok 'admin user /view/{id} IDOR guard'

if grep -RInE 'bot\.onText|node-telegram-bot-api|NodeSSH|sessions\[' "$ROOT/protect/payloads" >/dev/null 2>&1; then
  fail 'Telegram/SSH runtime wrapper leaked into payloads'
fi
ok 'payloads are Bash-installed PHP/Blade only'

if grep -RIn --exclude='security-test.sh' 'WilzzOfficial' "$ROOT" >/dev/null 2>&1; then
  fail 'old attribution remains'
fi
ok 'legacy attribution check'

printf '\nALL HARDENING TESTS PASSED\n'
[[ -f "$ROOT/modules/doctor.sh" ]] || fail 'health diagnostics module missing'
[[ -f "$ROOT/modules/backup.sh" ]] || fail 'backup module missing'
grep -q 'NanoXyinDev' "$ROOT/README.md" || fail 'GitHub attribution missing'
grep -q 'github.com/pterodactyl.png' "$ROOT/README.md" || fail 'Pterodactyl logo reference missing'
ok 'diagnostics, backups, README branding and attribution'
# API key controller compatibility checks
grep -q 'ApiKey::query()' "$ROOT/protect/payloads/18-ApiController.php" || fail 'admin API controller is not using current ApiKey query flow'
! grep -q 'ApiKeyRepositoryInterface' "$ROOT/protect/payloads/18-ApiController.php" || fail 'legacy API repository dependency remains'
grep -q 'DB::transaction' "$ROOT/protect/payloads/19-ApiKeyController.php" || fail 'client API key transaction guard missing'
grep -q 'lockForUpdate' "$ROOT/protect/payloads/19-ApiKeyController.php" || fail 'client API key concurrency guard missing'
ok 'API key controller compatibility and protection checks'


disk_guard="$ROOT/modules/disk-guard.sh"
[[ -f "$disk_guard" ]] || fail 'disk guard module missing'
bash -n "$disk_guard" || fail 'disk guard syntax error'
grep -q 'DISK_GUARD_THRESHOLD=100' "$disk_guard" || fail 'disk threshold is not 100%'
grep -q 'sleep 300' "$disk_guard" || fail 'post-delete cooldown missing'
grep -q 'ServerDeletionService' "$disk_guard" || fail 'Pterodactyl deletion service missing'
grep -q 'valid_server_uuid' "$disk_guard" || fail 'UUID safety guard missing'
grep -q 'while :' "$disk_guard" || fail 'continuous guard loop missing'
! grep -nE 'rm[[:space:]]+-rf.*\$|rm[[:space:]]+-rf.*volume' "$disk_guard" >/dev/null 2>&1 || fail 'unsafe raw rm deletion found in disk guard'
ok 'full disk guard safety checks'

THEME_FILE="$ROOT/modules/theme.sh"
grep -q 'templates/wrapper.blade.php' "$THEME_FILE" || fail 'theme installer does not support current wrapper layout'
grep -q 'zxv-protect-brand' "$THEME_FILE" || fail 'ZXV PROTECT branding injection missing'
grep -Fq "asset('zxvcode/mark.svg')" "$THEME_FILE" || fail 'ZXV PROTECT logo asset injection missing'
ok 'theme layout compatibility + ZXV PROTECT branding checks'

# Server workspace theme checks
grep -q 'zxv-server-theme' "$ROOT/themes/panel/theme.css" || fail 'server workspace theme scope missing'
grep -q 'premium server workspace skin' "$ROOT/themes/panel/theme.css" || fail 'server workspace theme documentation marker missing'
grep -q 'zxv:routechange' "$ROOT/modules/theme.sh" || fail 'SPA server route theme hook missing'
grep -q 'location.pathname' "$ROOT/modules/theme.sh" || fail 'server route detection missing'
grep -q 'xterm' "$ROOT/themes/panel/theme.css" || fail 'server console styling missing'
grep -q 'role="progressbar"' "$ROOT/themes/panel/theme.css" || fail 'server resource bar styling missing'
ok 'server workspace theme + SPA route + console/resource styling checks'
# Client dashboard/server-list theme and menu deduplication checks
grep -q 'zxv-dashboard-theme' "$ROOT/themes/panel/theme.css" || fail 'client dashboard theme scope missing'
grep -q 'isDashboard' "$ROOT/modules/theme.sh" || fail 'dashboard route detection missing'
[[ "$(grep -c 'install_wings' "$ROOT/modules/node.sh")" -eq 0 ]] || fail 'duplicate Wings command remains inside Node menu'
grep -q 'Panel + initial Node' "$ROOT/install.sh" || fail 'main setup menu was not consolidated'
ok 'client dashboard/server-list premium theme + duplicate Wings command removed'

