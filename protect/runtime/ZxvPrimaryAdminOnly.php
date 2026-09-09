<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ZxvPrimaryAdminOnly
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || (int) $user->id !== 1) {
            abort(403, 'Akses ditolak. Area ini hanya dapat dibuka oleh admin utama.');
        }

        return $next($request);
    }
}
