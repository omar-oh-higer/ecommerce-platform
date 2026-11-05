<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * When a cancelled order's reserved stock was actually given back to the inventory service.
     * Stays NULL while the release is pending (inventory service was down when the order was cancelled).
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('stock_released_at')->nullable()->after('total');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('stock_released_at');
        });
    }
};
