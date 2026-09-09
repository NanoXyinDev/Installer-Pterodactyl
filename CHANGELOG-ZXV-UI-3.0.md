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
