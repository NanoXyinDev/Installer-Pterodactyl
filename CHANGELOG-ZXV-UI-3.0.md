# ZXV UI 3.0

## Auth /auth/login
- Premium glass authentication surface with animated ambient orbs.
- More stable focus states and mobile sizing.
- Submit loading state with an 8-second safety reset.
- Reduced-motion support for accessibility.
- No third-party frontend dependency added.

## Dashboard / ZXV OFFICIAL
- Safer centered `ZXV OFFICIAL` identity with bounded width and mobile collision protection.
- Safe-area support for modern mobile browsers.
- Server cards remain responsive and do not force desktop widths.
- Existing Pterodactyl routes and React components remain the source of truth.

## Stability
- Reworked the theme `MutationObserver` to ignore ZXV-owned DOM changes.
- Added refresh debounce/guard to reduce React/theme redraw loops.
- Removed unsafe global animation targeting that affected nearly every rounded/shadow utility element.
- Kept the theme as a standalone CSS/JS overlay.

## Verification
- `node --check themes/panel/theme.js` passed.
- `bash -n` passed for installer shell scripts.
- `bash tests/security-test.sh` passed completely.


## ZXV UI 3.2 — Admin Stability + Canvas Greeting
- Fixed `/admin/zxv` 500 caused by the missing `admin.zxv.users.create` route.
- Existing installations now receive the missing route during Role System update.
- Dashboard tolerates an incomplete history migration and shows safe empty states.
- Added global progress feedback for forms and downloads.
- Stabilized the ZXV OFFICIAL brand and refresh cycle.
- Added a local canvas anime swordsman greeting with `HAI` text, without an external asset dependency.
- Left the Application API middleware unchanged to avoid breaking API consumers.

### UI 3.3
- Removed the extra archive wrapper directory from the distributable ZIP.
- Added a polished farewell screen when the main menu exits with `0` or `00`.


## 3.4 — Motion & Single Server
- Reworked HAI canvas to a short one-shot 3D-style anime greeting.
- Reduced persistent animation loops on dashboard UI.
- Locked managed server creation to the single name `server`.
- Added server-count guard to reject a second server.
- Preserved CEO/full-admin behavior for user ID 1.

## 3.4 — 3D Motion / Single Server / Primary Admin
- HAI greeting changed to a short one-shot 3D-style canvas animation (~2.4 seconds) with automatic teardown.
- ZXV OFFICIAL header badge uses a restrained 3D entrance/hover effect instead of long floating motion.
- Dashboard cards use subtle 3D interaction only; persistent heavy motion removed from the new polish layer.
- Server creation is locked to the single name `server` and a second server creation is rejected.
- Added a primary-admin migration and installer hardening so user ID 1 is always `root_admin=1` and ZXV role `ceo`.
