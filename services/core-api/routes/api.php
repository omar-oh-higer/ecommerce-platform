<?php

use Illuminate\Support\Facades\Route;

/*
| Every route in this file is served under /api/v1 (see bootstrap/app.php).
*/

Route::get('/', fn () => response()->json([
    'name' => config('app.name'),
    'version' => 'v1',
    'status' => 'ok',
]));
