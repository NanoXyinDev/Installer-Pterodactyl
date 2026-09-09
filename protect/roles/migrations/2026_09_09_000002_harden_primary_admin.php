<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        DB::table('users')->where('id', 1)->update(['root_admin' => 1]);

        if (Schema::hasTable('zxv_roles') && DB::table('users')->where('id', 1)->exists()) {
            DB::table('zxv_roles')->updateOrInsert(
                ['user_id' => 1],
                ['role' => 'ceo', 'assigned_by' => 1, 'updated_at' => now(), 'created_at' => now()]
            );
        }
    }

    public function down(): void
    {
        // Primary admin access is intentionally not downgraded on rollback.
    }
};
