#!/usr/bin/env bash
set -euo pipefail

ZXV_COMPAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../integrations/bangsano" && pwd)"
ZXV_COMPAT_OUT="/var/backups/zxvcode-ptero/compatibility"

compatibility_audit() {
  ui_section 'BANGSANO COMPATIBILITY CHECK'
  local root="$ZXV_COMPAT_ROOT" failed=0 file
  while IFS= read -r -d '' file; do
    if unzip -tq "$file" >/dev/null 2>&1; then
      ui_success "Archive aman dibaca: $(basename "$file")"
    else
      ui_error "Archive rusak: $(basename "$file")"
      failed=$((failed+1))
    fi
  done < <(find "$root/themes" -type f -name '*.zip' -print0)
  [[ -f "$root/assets/Pterodactyl_Nightcore_Theme.css" ]] && ui_success 'Nightcore CSS tersedia.' || failed=$((failed+1))
  [[ -f "$root/assets/background.jpg" ]] && ui_success 'Nightcore background tersedia.' || failed=$((failed+1))
  if (( failed == 0 )); then
    ui_success 'Compatibility bundle siap dipakai sebagai bahan opsional.'
  else
    ui_warning "$failed item perlu dicek lagi."
    return 1
  fi
}

list_compatibility_packages() {
  ui_section 'PAKET THEME LAMA YANG TERSEDIA'
  printf '  Stellar       — integrations/bangsano/themes/stellar.zip\n'
  printf '  Billing       — integrations/bangsano/themes/billing.zip\n'
  printf '  Enigma        — integrations/bangsano/assets/enigma.zip\n'
  printf '  Elysium       — integrations/bangsano/themes/ElysiumTheme.zip\n'
  printf '  Nebula        — integrations/bangsano/themes/nebulaptero.zip\n'
  printf '  Nightcore CSS — integrations/bangsano/assets/Pterodactyl_Nightcore_Theme.css\n'
  printf '  Nightcore IMG — integrations/bangsano/assets/background.jpg\n'
}

stage_compatibility_package() {
  require_root
  mkdir -p "$ZXV_COMPAT_OUT"
  local package="$1"
  local source=""
  case "$package" in
    stellar) source="$ZXV_COMPAT_ROOT/themes/stellar.zip";;
    billing) source="$ZXV_COMPAT_ROOT/themes/billing.zip";;
    enigma) source="$ZXV_COMPAT_ROOT/assets/enigma.zip";;
    elysium) source="$ZXV_COMPAT_ROOT/themes/ElysiumTheme.zip";;
    nebula) source="$ZXV_COMPAT_ROOT/themes/nebulaptero.zip";;
    *) ui_error 'Paket tidak dikenal.'; return 1;;
  esac
  [[ -f "$source" ]] || { ui_error 'Paket tidak ditemukan.'; return 1; }
  if ! unzip -tq "$source" >/dev/null 2>&1; then
    ui_error 'Paket theme tidak bisa dibaca.'
    return 1
  fi
  cp -f "$source" "$ZXV_COMPAT_OUT/$(basename "$source")"
  ui_success "$(basename "$source") sudah disalin ke $ZXV_COMPAT_OUT."
  ui_warning 'Belum gue pasang ke Panel. Bundle lama ini menyentuh core Panel, jadi gunakan setelah compatibility review.'
}

compatibility_menu() {
  while true; do
    ui_section 'KOMPATIBILITAS THEME'
    printf '  [01] Cek semua bundle\n  [02] Lihat paket\n  [03] Simpan Stellar\n  [04] Simpan Billing\n  [05] Simpan Enigma\n  [06] Simpan Elysium\n  [07] Simpan Nebula\n  [00] Kembali\n\n'
    read -r -p '  Pilih › ' choice
    case "$choice" in
      1|01) compatibility_audit || true;;
      2|02) list_compatibility_packages;;
      3|03) stage_compatibility_package stellar;;
      4|04) stage_compatibility_package billing;;
      5|05) stage_compatibility_package enigma;;
      6|06) stage_compatibility_package elysium;;
      7|07) stage_compatibility_package nebula;;
      0|00) return;;
      *) ui_warning 'Pilihan itu belum ada.';;
    esac
  done
}
