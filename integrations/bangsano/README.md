# BangSano compatibility bundle

ZXV keeps the older BangSano theme packages available as optional, inspectable bundles. They are **not installed automatically** because several of them patch old Pterodactyl core files and may be incompatible with the current Panel frontend.

Included:
- Stellar
- Billing
- Enigma
- Elysium
- Nebula Blueprint
- Nightcore CSS + background asset

The ZXV installer treats these as compatibility material rather than overwriting Panel source wholesale.

Safety notes:
- No hardcoded BangSano access token is used by ZXV.
- No `eval`-based Wings configuration is imported.
- No `curl | bash`/`wget | bash` execution path is imported.
- Theme bundles remain archives and are only staged after explicit user action.
