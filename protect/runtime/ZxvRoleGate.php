<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
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
            if (!ZxvRole::canOpenDashboard($user)) abort(403, 'Akses ZXV Admin Dashboard ditolak.');
            return $next($request);
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
