<?php

namespace Database\Seeders;

use App\Enums\Role;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        // The only way to get an admin: seeded from the environment, never through the API.
        $admin = User::firstOrNew(['email' => env('ADMIN_EMAIL', 'admin@store.test')]);
        $admin->name = 'Store Admin';
        $admin->password = env('ADMIN_PASSWORD', 'Admin@12345');
        $admin->role = Role::Admin;
        $admin->save();

        // Safe to run on every container start: creates the account only once.
        User::firstOrCreate(
            ['email' => 'customer@store.test'],
            ['name' => 'Test Customer', 'password' => 'password'],
        );
    }
}
