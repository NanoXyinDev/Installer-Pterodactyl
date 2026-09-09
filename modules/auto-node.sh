#!/usr/bin/env bash
set -euo pipefail

auto_node_wizard() {
  require_root
  local panel="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
  [[ -f "$panel/artisan" ]] || { ui_error 'Panel Pterodactyl belum terpasang.'; return 1; }
  ui_section 'NODE WIZARD'
  local location_name location_description node_name fqdn ram disk locid
  read -r -p '  Nama lokasi [Jakarta] › ' location_name
  location_name="${location_name:-Jakarta}"
  read -r -p '  Deskripsi lokasi [ZXV Node Location] › ' location_description
  location_description="${location_description:-ZXV Node Location}"
  read -r -p '  Nama node [NODE-01] › ' node_name
  node_name="${node_name:-NODE-01}"
  read -r -p '  FQDN node › ' fqdn
  [[ -n "$fqdn" ]] || { ui_error 'FQDN wajib diisi.'; return 1; }
  read -r -p '  RAM (MB) › ' ram
  read -r -p '  Disk (MB) › ' disk
  read -r -p '  Location ID › ' locid
  [[ "$ram" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ && "$locid" =~ ^[0-9]+$ ]] || { ui_error 'RAM, disk, dan Location ID harus berupa angka.'; return 1; }

  ui_run 'Membuat lokasi...' bash -c "cd \"$panel\" && printf '%s\\n%s\\n' \"$location_name\" \"$location_description\" | php artisan p:location:make"
  ui_run 'Membuat node...' bash -c "cd \"$panel\" && printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$node_name\" \"$location_description\" \"$locid\" 'https' \"$fqdn\" 'yes' 'no' 'no' \"$ram\" \"$ram\" \"$disk\" \"$disk\" '100' '8080' '2022' '/var/lib/pterodactyl/volumes' | php artisan p:node:make"
  ui_success 'Location dan node selesai dibuat tanpa menjalankan input sebagai shell command.'
}
