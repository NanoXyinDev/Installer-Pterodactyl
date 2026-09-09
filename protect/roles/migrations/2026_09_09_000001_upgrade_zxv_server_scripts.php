<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('zxv_server_script_history')) {
            Schema::create('zxv_server_script_history', function (Blueprint $table) {
                $table->id();
                $table->unsignedInteger('server_id')->index();
                $table->string('server_name', 191);
                $table->unsignedInteger('owner_id')->nullable()->index();
                $table->string('owner_username', 191)->nullable();
                $table->string('script_hash', 64)->index();
                $table->longText('startup_command');
                $table->timestamp('captured_at')->useCurrent()->index();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('zxv_server_script_history');
    }
};
