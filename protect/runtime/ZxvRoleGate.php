<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Models\Server;
use Pterodactyl\Support\ZxvRole;
use Symfony\Component\HttpFoundation\Response;

class ZxvRoleGate
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $role = ZxvRole::current($user);
        $path = trim($request->path(), '/');
        $method = strtoupper($request->method());

        if ($path === 'admin/zxv' || str_starts_with($path, 'admin/zxv/')) {
            if (!ZxvRole::canOpenDashboard($user)) abort(403, 'Akses ke dashboard ZXV ditolak.');
            return $next($request);
        }

        // ADP/OWNER boleh membuka halaman Admin Panel untuk melihat informasi,
        // tetapi tidak otomatis mendapatkan hak mutasi admin.
        if (in_array($role, [ZxvRole::ADP, ZxvRole::OWNER], true) && in_array($method, ['GET', 'HEAD'], true)) {
            return $next($request);
        }

        // Membuat/mengubah user admin (root_admin) tetap hanya untuk CEO.
        if (in_array($role, [ZxvRole::ADP, ZxvRole::OWNER], true)
            && preg_match('#^admin/users(?:/|$)#', $path)
            && in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)) {
            abort(403, 'ADP/OWNER tidak dapat membuat atau mengubah user Admin.');
        }

        if ($path === 'admin/servers/new' && $method === 'POST') {
            $requestedName = trim((string) $request->input('name'));
            if (strcasecmp($requestedName, 'server') !== 0) {
                abort(422, 'Nama server dikunci menjadi: server.');
            }
            if (Server::query()->exists()) {
                abort(409, 'Server sudah dibuat. Sistem hanya mengizinkan 1 server bernama server.');
            }
        }

        if ($role === ZxvRole::CEO) return $next($request);

        if (in_array($role, [ZxvRole::ADP, ZxvRole::OWNER], true)) {
            if (preg_match('#^admin/servers/new$#', $path) && in_array($method, ['GET', 'POST'], true)) {
                if ($role === ZxvRole::ADP && $method === 'POST') {
                    $ownerId = (int) $request->input('user');
                    if ($ownerId > 0 && $ownerId !== (int) $user->id) {
                        abort(403, 'ADP hanya boleh membuat server untuk akun sendiri.');
                    }
                }
                return $next($request);
            }
        }

        abort(403, 'Akses Admin Panel dibatasi oleh role ZXV.');
    }
}
