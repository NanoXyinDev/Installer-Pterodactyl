#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL: %s\n' "$1"; exit 1; }
ok(){ printf 'PASS: %s\n' "$1"; }

command -v php >/dev/null 2>&1 || fail 'php is required for payload syntax tests'

while IFS=$'\t' read -r id name dest rel sha; do
  [[ -n "$id" ]] || continue
  file="$ROOT/protect/$rel"
  [[ -f "$file" ]] || fail "missing payload $rel"
  [[ -n "$sha" && "$sha" != "-" ]] || fail "missing checksum for $rel"
  actual="$(sha256sum -- "$file" | awk '{print $1}')"
  [[ "$actual" == "$sha" ]] || fail "checksum mismatch $rel"
  if [[ "$file" == *.php ]]; then
    php -l "$file" >/dev/null || fail "PHP syntax error $rel"
  fi
done < "$ROOT/protect/manifest.tsv"
ok 'manifest checksums + PHP syntax'

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
ok 'attribution updated to XyrooXellz'

printf '\nALL HARDENING TESTS PASSED\n'
