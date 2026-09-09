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

RUNTIME_GUARD="$ROOT/protect/runtime/ZxvPrimaryAdminOnly.php"
[[ -f "$RUNTIME_GUARD" ]] || fail 'runtime primary-admin guard source missing'
php -l "$RUNTIME_GUARD" >/dev/null || fail 'runtime primary-admin guard syntax error'
grep -q 'class ZxvPrimaryAdminOnly' "$RUNTIME_GUARD" || fail 'primary-admin middleware class missing'
grep -q 'id !== 1' "$RUNTIME_GUARD" || fail 'primary-admin middleware does not enforce ID 1'
grep -q 'install_primary_admin_guard' "$ROOT/modules/protection.sh" || fail 'runtime guard installer missing'
grep -q 'ZxvPrimaryAdminOnly::class' "$ROOT/modules/protection.sh" || fail 'route middleware injection missing'
grep -q "'prefix' => 'nodes'" "$ROOT/modules/protection.sh" || fail 'nodes route guard target missing'
ok 'direct-route primary-admin hardening is present'

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
grep -q 'THEME_JS_SOURCE' "$THEME_FILE" || fail 'theme JS asset wiring missing'
grep -q 'ZXV PROTECT:ASSETS' "$THEME_FILE" || fail 'safe theme asset marker missing'
grep -q 'zxvcode-panel.js' "$THEME_FILE" || fail 'theme JS install path missing'
[[ -f "$ROOT/themes/panel/theme.js" ]] || fail 'theme JS source missing'
! grep -q '{{\|@php\|Auth::' "$ROOT/themes/panel/theme.js" || fail 'theme JS still depends on Blade/PHP interpolation'
ok 'theme layout compatibility + ZXV PROTECT branding checks'

# Server workspace theme checks
grep -q 'zxv-server-theme' "$ROOT/themes/panel/theme.css" || fail 'server workspace theme scope missing'
grep -q 'premium server workspace skin' "$ROOT/themes/panel/theme.css" || fail 'server workspace theme documentation marker missing'
grep -q 'zxv:routechange' "$ROOT/themes/panel/theme.js" || fail 'SPA server route theme hook missing'
grep -q 'window.location.pathname' "$ROOT/themes/panel/theme.js" || fail 'server route detection missing'
grep -q 'xterm' "$ROOT/themes/panel/theme.css" || fail 'server console styling missing'
grep -q 'role="progressbar"' "$ROOT/themes/panel/theme.css" || fail 'server resource bar styling missing'
ok 'server workspace theme + SPA route + console/resource styling checks'
# Client dashboard/server-list theme and menu deduplication checks
grep -q 'zxv-dashboard-theme' "$ROOT/themes/panel/theme.css" || fail 'client dashboard theme scope missing'
grep -q 'isDashboard' "$ROOT/themes/panel/theme.js" || fail 'dashboard route detection missing'
[[ "$(grep -c 'install_wings' "$ROOT/modules/node.sh")" -eq 0 ]] || fail 'duplicate Wings command remains inside Node menu'
grep -q '\[ + \] 1. Install Panel' "$ROOT/install.sh" || fail 'main setup menu was not consolidated'
grep -q 'Build & Pasang Lagi' "$ROOT/modules/theme.sh" || fail 'theme rebuild action is missing'
grep -q 'Lepas Theme' "$ROOT/modules/theme.sh" || fail 'theme uninstall action is missing'
grep -q 'Backup Theme' "$ROOT/modules/theme.sh" || fail 'theme backup action is missing from appearance menu'
grep -q 'THEME_SOURCE' "$ROOT/modules/theme.sh" || fail 'dashboard theme source wiring is missing'
[[ -f "$ROOT/themes/panel/theme.css" ]] || fail 'dashboard theme source file missing'
[[ "$(grep -c 'backup_theme_files' "$ROOT/modules/backup.sh")" -eq 0 ]] || fail 'theme backup remains duplicated in backup menu'
ok 'client dashboard/server-list premium theme + duplicate Wings command removed'
grep -q 'zxv-server-create-theme' "$ROOT/themes/panel/theme.css" || fail 'server create theme scope missing'
grep -q 'select2-selection--multiple' "$ROOT/themes/panel/theme.css" || fail 'allocation multi-select styling missing'
grep -q 'decorateCreateServer' "$ROOT/themes/panel/theme.js" || fail 'server create allocation decorator missing'
grep -q 'zxv-allocation-summary' "$ROOT/themes/panel/theme.js" || fail 'allocation summary UI missing'
ok 'server create form + allocation premium theme checks'


grep -q 'removeVolumeDirectory' "$ROOT/protect/payloads/10-ServerDeletionService.php" || fail 'server volume cleanup missing'
grep -q "'/var/lib/pterodactyl/volumes'" "$ROOT/protect/payloads/10-ServerDeletionService.php" || fail 'server volume root guard missing'
grep -q "str_starts_with(\$resolvedVolume" "$ROOT/protect/payloads/10-ServerDeletionService.php" || fail 'server volume containment guard missing'
! grep -q 'HALLO admin' "$ROOT/themes/panel/theme.js" || fail 'legacy greeting still embedded'
grep -q 'dayGreeting' "$ROOT/themes/panel/theme.js" || fail 'dynamic greeting missing'
grep -q 'SHOW ANOTHER SERVER' "$ROOT/themes/panel/theme.js" || fail 'other-server label missing'
grep -q 'zxv-guest-theme' "$ROOT/themes/panel/theme.js" || fail 'guest/login route theme class missing'
grep -q 'ZXV PROTECT 2.0 — guest/login refresh' "$ROOT/themes/panel/theme.css" || fail 'login visual refresh missing'
grep -q 'zxv-guest-theme .login-box' "$ROOT/themes/panel/theme.css" || fail 'legacy login card styling missing'
grep -q 'ZXV PROTECT 3.0 — STABLE MOTION / AUTH / MOBILE HARDENING' "$ROOT/themes/panel/theme.css" || fail 'login hardening theme missing'
grep -q 'enhanceGuest' "$ROOT/themes/panel/theme.js" || fail 'guest auth enhancement missing'
grep -q 'observerSuppressUntil' "$ROOT/themes/panel/theme.js" || fail 'mutation observer stability guard missing'
! grep -q '\[class\*=\"shadow-\"\].*\[class\*=\"rounded-\"\]' "$ROOT/themes/panel/theme.css" || fail 'unsafe global utility animation still present'
grep -q '8000' "$ROOT/themes/panel/theme.js" || fail 'auth loading safety timeout missing'
grep -q 'theme_version' "$ROOT/modules/theme.sh" || fail 'theme cache-busting version missing'
ok 'login/admin visual refresh + cache-busting checks'

ROLE_FILE="$ROOT/protect/runtime/ZxvRole.php"
ROLE_GATE="$ROOT/protect/runtime/ZxvRoleGate.php"
ROLE_CONTROLLER="$ROOT/protect/roles/ZxvAdminController.php"
ROLE_MIGRATION="$ROOT/protect/roles/migrations/2026_09_09_000000_create_zxv_role_tables.php"
[[ -f "$ROLE_FILE" && -f "$ROLE_GATE" && -f "$ROLE_CONTROLLER" && -f "$ROLE_MIGRATION" ]] || fail 'ZXV role system source files missing'
php -l "$ROLE_FILE" >/dev/null || fail 'ZXV role helper syntax error'
php -l "$ROLE_GATE" >/dev/null || fail 'ZXV role gate syntax error'
php -l "$ROLE_CONTROLLER" >/dev/null || fail 'ZXV admin controller syntax error'
php -l "$ROLE_MIGRATION" >/dev/null || fail 'ZXV role migration syntax error'
grep -q "USER.*ADP.*OWNER.*CEO" "$ROOT/modules/roles.sh" || fail 'role hierarchy missing'
grep -q "admin.zxv.dashboard" "$ROOT/modules/roles.sh" || fail 'ZXV dashboard route missing'
grep -q "admin.zxv.server.script.download" "$ROOT/modules/roles.sh" || fail 'server script download route missing'
grep -q "zxv_server_script_history" "$ROOT/protect/roles/ZxvAdminController.php" || fail 'server script history storage missing'
grep -q "downloadServerScript" "$ROOT/protect/roles/ZxvAdminController.php" || fail 'server script download missing'
grep -q "downloadServerScript" "$ROOT/modules/roles.sh" || fail 'server script route missing'
grep -q "ZxvRoleGate::class" "$ROOT/modules/roles.sh" || fail 'global role gate wiring missing'
grep -q "canCreateServer" "$ROOT/protect/runtime/ZxvRole.php" || fail 'ADP server permission missing'
ok 'ZXV role hierarchy + admin dashboard + per-server script history/download checks'
bash -n "$ROOT/modules/roles.sh" || fail 'role module shell syntax error'
bash -n "$ROOT/protect-install.sh" || fail 'standalone protection installer syntax error'
grep -q 'ZXV ROLE MENU' "$ROOT/protect/payloads/23-admin.blade.php" || fail 'role-aware admin layout marker missing'
grep -q "ZxvRole::is('ceo'" "$ROOT/protect/payloads/23-admin.blade.php" || fail 'CEO-only native admin links missing'
grep -q 'source "$BASE_DIR/modules/roles.sh"' "$ROOT/protect-install.sh" || fail 'standalone protection installer does not load role system'
grep -q 'zxv_roles_install' "$ROOT/modules/protection.sh" || fail 'protection manager does not resync role system'
ok 'role-aware admin layout + standalone protection integration checks'
