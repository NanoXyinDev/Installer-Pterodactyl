<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\Schema\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('zxv_roles') || !Schema::hasTable('users')) {
            return;
        }

        $userIds = DB::table('zxv_roles')
            ->whereIn('role', ['user', 'adp', 'owner'])
            ->pluck('user_id')
            ->map(fn ($id) => (int) $id)
            ->filter(fn ($id) => $id !== 1)
            ->values()
            ->all();

        if ($userIds) {
            DB::table('users')->whereIn('id', $userIds)->update(['root_admin' => false]);
        }

        DB::table('users')->where('id', 1)->update(['root_admin' => true]);
        DB::table('zxv_roles')->updateOrInsert(
            ['user_id' => 1],
            ['role' => 'ceo', 'assigned_by' => 1, 'updated_at' => now(), 'created_at' => now()]
        );
    }

    public function down(): void
    {
        // Intentionally non-reversible: removing root_admin from delegated ZXV roles
        // is a security hardening step. ID 1 remains the primary administrator.
    }
};
