<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Pterodactyl\Models\Server;
use Pterodactyl\Models\User;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Support\ZxvRole;
use Pterodactyl\Http\Controllers\Controller;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ZxvAdminController extends Controller
{
    public function index(Request $request): Response
    {
        $this->assertDashboard($request);

        $users = User::query()
            ->select('users.*')
            ->selectRaw('(SELECT COUNT(*) FROM servers WHERE servers.owner_id = users.id) AS servers_count')
            ->orderByDesc('users.id')
            ->limit(500)
            ->get();

        $servers = Server::query()
            ->with(['owner:id,username,email', 'egg:id,name'])
            ->latest('servers.id')
            ->limit(500)
            ->get();

        $hasHistory = Schema::hasTable('zxv_server_script_history');
        if ($hasHistory) {
            $this->syncServerScriptHistory();
        }

        $history = $hasHistory
            ? DB::table('zxv_server_script_history')->orderByDesc('captured_at')->limit(500)->get()
            : collect();

        $roles = [];
        foreach ($users as $user) {
            $roles[$user->id] = ZxvRole::current($user);
        }

        return response()->view('admin.zxv.dashboard', [
            'role' => ZxvRole::current($request->user()),
            'users' => $users,
            'servers' => $servers,
            'history' => $history,
            'roles' => $roles,
            'stats' => [
                'users' => User::count(),
                'servers' => Server::count(),
                'nodes' => Schema::hasTable('nodes') ? DB::table('nodes')->count() : 0,
                'scripts' => $hasHistory ? DB::table('zxv_server_script_history')->distinct()->count('server_id') : 0,
            ],
        ]);
    }

    public function createUser(Request $request): Response
    {
        $actor = $request->user();
        $role = strtolower((string) $request->input('role'));
        abort_unless(in_array($role, [ZxvRole::ADP, ZxvRole::OWNER], true), 422, 'Role user baru tidak valid.');
        abort_unless(ZxvRole::canAssign($role, $actor), 403, 'Anda tidak dapat membuat role ini.');

        $data = $request->validate([
            'email' => ['required', 'email', 'max:191', 'unique:users,email'],
            'username' => ['required', 'string', 'max:191', 'regex:/^[A-Za-z0-9._-]+$/', 'unique:users,username'],
            'name_first' => ['required', 'string', 'max:191'],
            'name_last' => ['required', 'string', 'max:191'],
            'password' => ['required', 'string', 'min:10', 'max:255'],
        ]);
        $data['language'] = 'en';
        // Akun yang dibuat lewat Role System tetap user biasa di Pterodactyl.
        // Akses Admin Panel dikelola oleh role ZXV, bukan root_admin.
        $data['root_admin'] = false;

        $user = app(UserCreationService::class)->handle($data);
        abort_unless(Schema::hasTable('zxv_roles'), 500, 'ZXV role database belum terpasang. Jalankan update Role System.');

        DB::table('zxv_roles')->updateOrInsert(
            ['user_id' => $user->id],
            ['role' => $role, 'assigned_by' => $actor->id, 'updated_at' => now(), 'created_at' => now()]
        );

        return redirect()->route('admin.zxv.dashboard')->with('success', strtoupper($role) . ' berhasil dibuat.');
    }

    public function updateRole(Request $request): Response
    {
        $actor = $request->user();
        $target = User::query()->findOrFail((int) $request->input('user_id'));
        $role = strtolower((string) $request->input('role'));

        abort_unless(in_array($role, [ZxvRole::USER, ZxvRole::ADP, ZxvRole::OWNER], true), 422, 'Role tidak valid.');
        abort_unless(ZxvRole::canTouchUser($target, $actor), 403, 'Anda tidak dapat mengubah akun ini.');
        abort_unless(ZxvRole::canAssign($role, $actor), 403, 'Role ini tidak dapat diberikan oleh akun Anda.');

        abort_unless(Schema::hasTable('zxv_roles'), 500, 'ZXV role database belum terpasang. Jalankan update Role System.');

        DB::transaction(function () use ($target, $role, $actor) {
            DB::table('zxv_roles')->updateOrInsert(
                ['user_id' => $target->id],
                ['role' => $role, 'assigned_by' => $actor->id, 'updated_at' => now(), 'created_at' => now()]
            );
            // Role ZXV tidak memberikan root_admin. Full Admin tetap khusus ID 1/CEO.
            $target->forceFill(['root_admin' => false])->saveOrFail();
        });

        return redirect()->route('admin.zxv.dashboard')->with('success', 'Role user berhasil diperbarui.');
    }

    public function downloadServerScript(Request $request, Server $server): StreamedResponse
    {
        $this->assertDashboard($request);
        $script = (string) $server->startup;
        $filename = $this->serverFilename($server) . '-startup.sh';
        return response()->streamDownload(function () use ($server, $script) {
            echo "#!/bin/sh\n";
            echo "# ZXV SERVER SCRIPT\n";
            echo "# Server: " . str_replace(["\r", "\n"], ' ', $server->name) . "\n\n";
            echo $script . "\n";
        }, $filename, ['Content-Type' => 'text/plain; charset=UTF-8']);
    }

    public function downloadHistory(Request $request, int $history): StreamedResponse
    {
        $this->assertDashboard($request);
        $row = DB::table('zxv_server_script_history')->where('id', $history)->firstOrFail();
        $filename = $this->safeFilename($row->server_name) . '-' . substr($row->script_hash, 0, 12) . '.sh';
        return response()->streamDownload(function () use ($row) {
            echo "#!/bin/sh\n";
            echo "# ZXV SERVER SCRIPT HISTORY\n";
            echo "# Server: " . str_replace(["\r", "\n"], ' ', $row->server_name) . "\n\n";
            echo $row->startup_command . "\n";
        }, $filename, ['Content-Type' => 'text/plain; charset=UTF-8']);
    }

    private function assertDashboard(Request $request): void
    {
        abort_unless(ZxvRole::canOpenDashboard($request->user()), 403, 'Akses dashboard ditolak.');
    }

    private function syncServerScriptHistory(): void
    {
        try {
            Server::query()->with('owner:id,username')->chunkById(200, function ($servers) {
                foreach ($servers as $server) {
                    $script = (string) $server->startup;
                    if ($script === '') continue;
                    $hash = hash('sha256', $script);
                    $exists = DB::table('zxv_server_script_history')
                        ->where('server_id', $server->id)
                        ->where('script_hash', $hash)
                        ->exists();
                    if ($exists) continue;
                    DB::table('zxv_server_script_history')->insert([
                        'server_id' => $server->id,
                        'server_name' => $server->name,
                        'owner_id' => $server->owner_id,
                        'owner_username' => optional($server->owner)->username,
                        'script_hash' => $hash,
                        'startup_command' => $script,
                        'captured_at' => now(),
                    ]);
                }
            });
        } catch (\Throwable $e) {
            Log::warning('ZXV server script history sync failed', ['error' => $e->getMessage()]);
        }
    }

    private function safeFilename(string $value): string
    {
        return preg_replace('/[^A-Za-z0-9._-]+/', '-', $value) ?: 'server';
    }

    private function serverFilename(Server $server): string
    {
        return $this->safeFilename((string) $server->name) . '-' . substr((string) $server->uuid, 0, 8);
    }
}
