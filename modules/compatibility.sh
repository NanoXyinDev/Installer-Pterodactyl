#!/usr/bin/env bash
set -euo pipefail

ZXV_COMPAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../integrations/bangsano" && pwd)"
ZXV_COMPAT_OUT="/var/backups/zxvcode-ptero/compatibility"

compatibility_audit() {
  ui_section 'ZXV × SANO COLLAB AUDIT'
  local root="$ZXV_COMPAT_ROOT" failed=0 file
  while IFS= read -r -d '' file; do
    if unzip -tq "$file" >/dev/null 2>&1; then
      ui_success "Paket aman dibaca: $(basename "$file")"
    else
      ui_error "Paket rusak: $(basename "$file")"
      failed=$((failed+1))
    fi
  done < <(find "$root/themes" -type f -name '*.zip' -print0)
  [[ -f "$root/assets/Pterodactyl_Nightcore_Theme.css" ]] && ui_success 'Nightcore CSS tersedia.' || failed=$((failed+1))
  [[ -f "$root/assets/background.jpg" ]] && ui_success 'Background Nightcore tersedia.' || failed=$((failed+1))
  [[ -f "$root/source-reference/index.tsx" ]] && ui_success 'Reference frontend Sano tersedia.' || failed=$((failed+1))
  if (( failed == 0 )); then
    ui_success 'Semua komponen collab siap dipakai atau diaudit.'
  else
    ui_warning "$failed item perlu dicek lagi."
    return 1
  fi
}

list_compatibility_packages() {
  ui_section 'PAKET THEME — ZXV × SANO'
  printf '  [01] Stellar      — theme archive\n'
  printf '  [02] Billing      — theme archive\n'
  printf '  [03] Enigma       — theme archive\n'
  printf '  [04] Elysium      — theme archive\n'
  printf '  [05] Nebula       — theme archive\n'
  printf '  [06] Nightcore    — CSS + background\n'
  printf '  [07] Semua paket  — collab bundle\n'
  printf '  [08] Source ref   — frontend/node reference\n'
}

stage_compatibility_package() {
  require_root
  mkdir -p "$ZXV_COMPAT_OUT"
  local package="${1:-}" source="" label=""
  case "$package" in
    stellar) source="$ZXV_COMPAT_ROOT/themes/stellar.zip"; label='Stellar';;
    billing) source="$ZXV_COMPAT_ROOT/themes/billing.zip"; label='Billing';;
    enigma) source="$ZXV_COMPAT_ROOT/assets/enigma.zip"; label='Enigma';;
    elysium) source="$ZXV_COMPAT_ROOT/themes/ElysiumTheme.zip"; label='Elysium';;
    nebula) source="$ZXV_COMPAT_ROOT/themes/nebulaptero.zip"; label='Nebula';;
    *) ui_error 'Paket theme itu belum tersedia.'; return 1;;
  esac
  [[ -f "$source" ]] || { ui_error "Paket $label belum ditemukan."; return 1; }
  unzip -tq "$source" >/dev/null 2>&1 || { ui_error "Paket $label rusak."; return 1; }
  cp -f "$source" "$ZXV_COMPAT_OUT/$(basename "$source")"
  ui_success "$label sudah disiapkan di $ZXV_COMPAT_OUT."
  ui_warning 'Belum dipasang ke Panel otomatis. Theme legacy bisa menyentuh core, jadi aktivasi dilakukan setelah compatibility review.'
}

stage_nightcore() {
  require_root
  mkdir -p "$ZXV_COMPAT_OUT/nightcore"
  cp -f "$ZXV_COMPAT_ROOT/assets/Pterodactyl_Nightcore_Theme.css" "$ZXV_COMPAT_OUT/nightcore/Nightcore.css"
  cp -f "$ZXV_COMPAT_ROOT/assets/background.jpg" "$ZXV_COMPAT_OUT/nightcore/background.jpg"
  ui_success 'Nightcore CSS dan background sudah disiapkan sebagai paket aman untuk review.'
}

stage_all_collab() {
  require_root
  mkdir -p "$ZXV_COMPAT_OUT/all"
  local src
  for src in "$ZXV_COMPAT_ROOT"/themes/*.zip "$ZXV_COMPAT_ROOT"/assets/enigma.zip "$ZXV_COMPAT_ROOT"/assets/Pterodactyl_Nightcore_Theme.css "$ZXV_COMPAT_ROOT"/assets/background.jpg; do
    [[ -f "$src" ]] && cp -f "$src" "$ZXV_COMPAT_OUT/all/"
  done
  ui_success 'Paket ZXV × Sano lengkap sudah disiapkan untuk dipilih per theme.'
  ui_warning 'Archive legacy tidak akan menimpa source Panel tanpa tindakan eksplisit.'
}

show_source_reference() {
  ui_section 'SOURCE REFERENCE'
  printf '  Frontend reference : integrations/bangsano/source-reference/index.tsx\n'
  printf '  Location reference : integrations/bangsano/source-reference/alocation.sh\n'
  printf '  Node reference     : integrations/bangsano/source-reference/createnode.sh\n'
  printf '  Catatan            : hanya referensi; tidak dijalankan otomatis.\n'
}

compatibility_menu() {
  while true; do
    ui_section 'ZXV × SANO COLLAB'
    printf '  [01] Cek semua paket\n  [02] Lihat daftar theme\n  [03] Siapkan Stellar\n  [04] Siapkan Billing\n  [05] Siapkan Enigma\n  [06] Siapkan Elysium\n  [07] Siapkan Nebula\n  [08] Siapkan Nightcore\n  [09] Siapkan semua paket\n  [10] Lihat source reference\n  [00] Kembali\n\n'
    read -r -p '  Pilih › ' choice
    case "$choice" in
      1|01) compatibility_audit || true;;
      2|02) list_compatibility_packages;;
      3|03) stage_compatibility_package stellar;;
      4|04) stage_compatibility_package billing;;
      5|05) stage_compatibility_package enigma;;
      6|06) stage_compatibility_package elysium;;
      7|07) stage_compatibility_package nebula;;
      8|08) stage_nightcore;;
      9|09) stage_all_collab;;
      10) show_source_reference;;
      0|00) return;;
      *) ui_warning 'Pilihan itu belum ada.';;
    esac
  done
}
