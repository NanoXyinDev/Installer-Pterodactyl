<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {}

    /**
     * Aktifkan mode "Force Delete"
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * 🧱 NDyProtect v1.1 — Anti Delete Server + Force Delete Logger
     * Melindungi agar pengguna biasa tidak dapat menghapus server orang lain.
     * Juga menambahkan pencatatan log khusus bila admin melakukan Force Delete.
     */
    public function handle(Server $server): void
    {
        $user = Auth::user();

        // 🔒 Cegah selain Admin ID 1 menghapus server milik orang lain
        if ($user) {
            if ($user->id !== 1) {
                $ownerId = $server->owner_id
                    ?? $server->user_id
                    ?? ($server->owner?->id ?? null)
                    ?? ($server->user?->id ?? null);

                if ($ownerId === null) {
                    throw new DisplayException('Akses ditolak: informasi pemilik server tidak tersedia.');
                }

                if ($ownerId !== $user->id) {
                    throw new DisplayException('🚫 Akses ditolak: Hanya Admin ID 1 yang dapat menghapus server orang lain! ©Protect By @XyrooXellz');
                }
            }
        }

        // 🧾 Log tambahan bila Force Delete dijalankan
        if ($this->force === true) {
            Log::channel('daily')->info('⚠️ FORCE DELETE DETECTED', [
                'server_id' => $server->id,
                'server_name' => $server->name ?? 'Unknown',
                'deleted_by' => $user?->id ?? 'CLI/Unknown',
                'time' => now()->toDateTimeString(),
            ]);

            Log::build([
                'driver' => 'single',
                'path' => storage_path('logs/force_delete.log'),
            ])->info("⚠️ FORCE DELETE SERVER #{$server->id} ({$server->name}) oleh User ID {$user?->id}");
        }

        // 🔧 Hapus data dari Daemon (Wings)
        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }
            Log::warning($exception);
        }

        // 🧹 Bersihkan folder volume server jika Wings tidak lagi memilikinya.
        // Hanya path volume Pterodactyl yang valid dan UUID server yang boleh disentuh.
        try {
            $uuid = (string) $server->uuid;
            $root = realpath('/var/lib/pterodactyl/volumes');
            if ($root !== false && preg_match('/^[a-f0-9-]{36}$/i', $uuid)) {
                $volume = $root . DIRECTORY_SEPARATOR . $uuid;
                $resolvedRoot = realpath($root);
                $resolvedVolume = is_dir($volume) ? realpath($volume) : false;
                if ($resolvedRoot !== false && $resolvedVolume !== false
                    && str_starts_with($resolvedVolume . DIRECTORY_SEPARATOR, $resolvedRoot . DIRECTORY_SEPARATOR)) {
                    $this->removeVolumeDirectory($resolvedVolume);
                }
            }
        } catch (\Throwable $exception) {
            Log::warning('Unable to clean server volume after deletion.', [
                'server_id' => $server->id,
                'server_uuid' => $server->uuid,
                'error' => $exception->getMessage(),
            ]);
            if (!$this->force) {
                throw $exception;
            }
        }

        // 🧹 Hapus database & record panel
        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) throw $exception;
                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }
    private function removeVolumeDirectory(string $path): void
    {
        $items = scandir($path);
        if ($items === false) {
            return;
        }

        foreach ($items as $item) {
            if ($item === '.' || $item === '..') {
                continue;
            }

            $child = $path . DIRECTORY_SEPARATOR . $item;
            if (is_link($child) || is_file($child)) {
                @unlink($child);
                continue;
            }

            if (is_dir($child)) {
                $this->removeVolumeDirectory($child);
            }
        }

        @rmdir($path);
    }

}