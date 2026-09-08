# Protection source audit

Source: `protect.js`

- Source lines: 8170
- Logical entries in Protect All: 24
- Unique destination files: 23
- Destination collision: `/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php` appears twice in the source; the installer keeps the first complete implementation instead of overwriting the same path twice.
- Named protect handlers in the source: PROTECT1 through PROTECT14. There is no separate PROTECT15 handler in the supplied source.
- The Telegram wrapper (`bot.onText`, `bot.sendMessage`, `sessions`, `NodeSSH` orchestration) is not included in the new installer runtime. The PHP/Blade payloads are installed by Bash.


## V4 hardening

- Attribution in protection payloads updated to `©Protect By @XyrooXellz`.
- `Admin/UserController.php::view(User $user)` now enforces an IDOR guard: only admin ID 1 or the same authenticated user may open the user detail page.
- Added `tests/security-test.sh` for checksum, PHP syntax, wrapper-leak, attribution, and `/view/{id}` guard regression checks.
- This fix targets the supplied source's missing authorization check in `UserController::view`; other `/view/{id}` endpoints in the supplied payloads already contain explicit admin/ownership checks.
