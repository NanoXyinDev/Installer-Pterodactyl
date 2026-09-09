#!/usr/bin/env bash
set -euo pipefail
ROLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../protect" && pwd)/roles"
RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../protect/runtime" && pwd)"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"

zxv_roles_install(){
  require_root
  [[ -f "$PANEL_DIR/artisan" ]] || { ui_error 'Pterodactyl Panel belum terpasang.'; return 1; }
  [[ -f "$ROLE_ROOT/ZxvAdminController.php" && -f "$RUNTIME_ROOT/ZxvRole.php" && -f "$RUNTIME_ROOT/ZxvRoleGate.php" ]] || { ui_error 'Role runtime source tidak lengkap.'; return 1; }
  local middleware_dir="$PANEL_DIR/app/Http/Middleware" support_dir="$PANEL_DIR/app/Support" controller_dir="$PANEL_DIR/app/Http/Controllers/Admin" view_dir="$PANEL_DIR/resources/views/admin/zxv" migration_dir="$PANEL_DIR/database/migrations"
  mkdir -p "$middleware_dir" "$support_dir" "$controller_dir" "$view_dir" "$migration_dir"
  backup_file "$middleware_dir/ZxvRoleGate.php" >/dev/null
  backup_file "$support_dir/ZxvRole.php" >/dev/null
  backup_file "$controller_dir/ZxvAdminController.php" >/dev/null
  install -m 0644 "$RUNTIME_ROOT/ZxvRoleGate.php" "$middleware_dir/ZxvRoleGate.php"
  install -m 0644 "$RUNTIME_ROOT/ZxvRole.php" "$support_dir/ZxvRole.php"
  install -m 0644 "$ROLE_ROOT/ZxvAdminController.php" "$controller_dir/ZxvAdminController.php"
  install -m 0644 "$ROLE_ROOT/views/dashboard.blade.php" "$view_dir/dashboard.blade.php"
  install -m 0644 "$ROLE_ROOT/migrations/2026_09_09_000000_create_zxv_role_tables.php" "$migration_dir/2026_09_09_000000_create_zxv_role_tables.php"
  install -m 0644 "$ROLE_ROOT/migrations/2026_09_09_000001_upgrade_zxv_server_scripts.php" "$migration_dir/2026_09_09_000001_upgrade_zxv_server_scripts.php"
  php -l "$middleware_dir/ZxvRoleGate.php" >/dev/null
  php -l "$support_dir/ZxvRole.php" >/dev/null
  php -l "$controller_dir/ZxvAdminController.php" >/dev/null
  php -l "$migration_dir/2026_09_09_000000_create_zxv_role_tables.php" >/dev/null

  local routes="$PANEL_DIR/routes/admin.php" provider="$PANEL_DIR/app/Providers/RouteServiceProvider.php"
  [[ -f "$routes" && -f "$provider" ]] || { ui_error 'Route files Pterodactyl tidak lengkap.'; return 1; }
  backup_file "$routes" >/dev/null
  backup_file "$provider" >/dev/null
  python3 - "$routes" "$provider" <<'PYTHON'
from pathlib import Path
import sys
routes = Path(sys.argv[1]); provider = Path(sys.argv[2])
text = routes.read_text(encoding='utf-8')
imp = 'use Pterodactyl\\Http\\Controllers\\Admin\\ZxvAdminController;'
if imp not in text:
    text = text.replace('use Pterodactyl\\Http\\Controllers\\Admin;', 'use Pterodactyl\\Http\\Controllers\\Admin;\n' + imp, 1)
block = """\nRoute::prefix('zxv')->group(function () {\n    Route::get('/', [ZxvAdminController::class, 'index'])->name('admin.zxv.dashboard');\n    Route::post('/roles', [ZxvAdminController::class, 'updateRole'])->name('admin.zxv.roles');\n    Route::get('/servers/{server}/script/download', [ZxvAdminController::class, 'downloadServerScript'])->name('admin.zxv.server.script.download');\n    Route::get('/scripts/history/{history}/download', [ZxvAdminController::class, 'downloadHistory'])->name('admin.zxv.script.history.download');\n});\n"""
if "name('admin.zxv.dashboard')" not in text:
    marker = "Route::get('/', [Admin\\BaseController::class, 'index'])->name('admin.index');"
    text = text.replace(marker, marker + block, 1)
routes.write_text(text, encoding='utf-8')
text = provider.read_text(encoding='utf-8')
imp = 'use Pterodactyl\\Http\\Middleware\\ZxvRoleGate;'
if imp not in text:
    text = text.replace('use Pterodactyl\\Http\\Middleware\\AdminAuthenticate;', 'use Pterodactyl\\Http\\Middleware\\AdminAuthenticate;\n' + imp, 1)
text = text.replace("Route::middleware(['auth.session', RequireTwoFactorAuthentication::class, AdminAuthenticate::class])", "Route::middleware(['auth.session', RequireTwoFactorAuthentication::class, AdminAuthenticate::class, ZxvRoleGate::class])", 1)
text = text.replace("Route::middleware(['application-api', 'throttle:api.application'])", "Route::middleware(['application-api', ZxvRoleGate::class, 'throttle:api.application'])", 1)
provider.write_text(text, encoding='utf-8')
PYTHON

  (cd "$PANEL_DIR" && php artisan migrate --force) >/dev/null

  python3 - "$PANEL_DIR/resources/views/layouts/admin.blade.php" <<'PYTHON'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
marker='{{-- ZXV ROLE MENU --}}'
injection='''{{-- ZXV ROLE MENU --}}\n@if(\\Pterodactyl\\Support\\ZxvRole::canOpenDashboard(Auth::user()))\n<li class="header">ZXV MANAGEMENT</li>\n<li class="{{ ! starts_with(Route::currentRouteName(), 'admin.zxv') ?: 'active' }}"><a href="{{ route('admin.zxv.dashboard') }}"><i class="fa fa-dashboard"></i> <span>ZXV Admin Dashboard</span></a></li>\n@endif\n@if(\\Pterodactyl\\Support\\ZxvRole::canCreateServer(Auth::user()))\n<li><a href="{{ route('admin.servers.new') }}"><i class="fa fa-plus-circle"></i> <span>Create Server</span></a></li>\n@endif\n'''
if marker not in s:
    s=s.replace('<ul class="sidebar-menu">','<ul class="sidebar-menu">\n'+injection,1)
blocks=[]
blocks.append(('''                        <li class="{{ Route::currentRouteName() !== 'admin.index' ?: 'active' }}">\n                            <a href="{{ route('admin.index') }}">\n                                <i class="fa fa-home"></i> <span>Overview</span>\n                            </a>\n                        </li>''','''@if(\\Pterodactyl\\Support\\ZxvRole::is('ceo', Auth::user()))\n                        <li class="{{ Route::currentRouteName() !== 'admin.index' ?: 'active' }}">\n                            <a href="{{ route('admin.index') }}">\n                                <i class="fa fa-home"></i> <span>Overview</span>\n                            </a>\n                        </li>\n@endif'''))
blocks.append(('''                        <li class="{{ ! starts_with(Route::currentRouteName(), 'admin.servers') ?: 'active' }}">\n                            <a href="{{ route('admin.servers') }}">\n                                <i class="fa fa-server"></i> <span>Servers</span>\n                            </a>\n                        </li>''','''@if(\\Pterodactyl\\Support\\ZxvRole::is('ceo', Auth::user()))\n                        <li class="{{ ! starts_with(Route::currentRouteName(), 'admin.servers') ?: 'active' }}">\n                            <a href="{{ route('admin.servers') }}">\n                                <i class="fa fa-server"></i> <span>Servers</span>\n                            </a>\n                        </li>\n@endif'''))
blocks.append(('''                        <li class="{{ ! starts_with(Route::currentRouteName(), 'admin.users') ?: 'active' }}">\n                            <a href="{{ route('admin.users') }}">\n                                <i class="fa fa-users"></i> <span>Users</span>\n                            </a>\n                        </li>''','''@if(\\Pterodactyl\\Support\\ZxvRole::is('ceo', Auth::user()))\n                        <li class="{{ ! starts_with(Route::currentRouteName(), 'admin.users') ?: 'active' }}">\n                            <a href="{{ route('admin.users') }}">\n                                <i class="fa fa-users"></i> <span>Users</span>\n                            </a>\n                        </li>\n@endif'''))
for old,new in blocks:
    if old in s: s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PYTHON

  (cd "$PANEL_DIR" && php artisan view:clear >/dev/null 2>&1 && php artisan view:cache >/dev/null 2>&1) || { ui_error 'Role menu Blade check gagal.'; return 1; }
  (cd "$PANEL_DIR" && php artisan tinker --execute="DB::table('zxv_roles')->updateOrInsert(['user_id'=>1],['role'=>'ceo','assigned_by'=>1,'updated_at'=>now(),'created_at'=>now()]); DB::table('users')->where('id',1)->update(['root_admin'=>1]);") >/dev/null 2>&1 || true
  (cd "$PANEL_DIR" && php artisan optimize:clear >/dev/null 2>&1) || true
  ui_success 'ZXV Role System aktif: USER → ADP → OWNER → CEO.'
  ui_info 'ADP: hanya Create Server. OWNER: Dashboard + ADP management. CEO: full Admin Dashboard + OWNER/ADP management. Dashboard membaca startup script tiap server.'
}

zxv_roles_audit(){
  local panel="$PANEL_DIR" failed=0
  ui_section 'ROLE SYSTEM AUDIT'
  for file in "$panel/app/Support/ZxvRole.php" "$panel/app/Http/Middleware/ZxvRoleGate.php" "$panel/app/Http/Controllers/Admin/ZxvAdminController.php" "$panel/resources/views/admin/zxv/dashboard.blade.php" "$panel/database/migrations/2026_09_09_000001_upgrade_zxv_server_scripts.php"; do
    if [[ -f "$file" ]] && php -l "$file" >/dev/null 2>&1; then ui_success "OK $(basename "$file")"; else ui_error "BROKEN/MISSING $(basename "$file")"; failed=$((failed+1)); fi
  done
  grep -q "admin.zxv.dashboard" "$panel/routes/admin.php" 2>/dev/null && ui_success 'ZXV dashboard routes: OK' || { ui_error 'ZXV dashboard routes: MISSING'; failed=$((failed+1)); }
  grep -q 'ZxvRoleGate::class' "$panel/app/Providers/RouteServiceProvider.php" 2>/dev/null && ui_success 'Global admin role gate: OK' || { ui_error 'Global admin role gate: MISSING'; failed=$((failed+1)); }
  ((failed==0))
}

roles_menu(){
  while true; do
    ui_section 'ROLE & ADMIN DASHBOARD'
    printf '  [ + ] 1. Pasang / Update Role System\n  [ + ] 2. Audit Role System\n  [ + ] 0. Kembali\n\n'
    read -r -p '  Pilih › ' choice
    case "$choice" in
      1|01) zxv_roles_install;;
      2|02) zxv_roles_audit;;
      0|00) return;;
      *) ui_warning 'Pilihan itu belum ada.';;
    esac
  done
}
