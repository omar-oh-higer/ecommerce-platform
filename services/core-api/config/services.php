<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    // Inventory service (see proto/inventory.proto).
    'inventory' => [
        // "grpc": the .NET inventory service (Docker). "fake": in-app stand-in (tests, or PHP without ext-grpc).
        'driver' => env('INVENTORY_DRIVER', 'grpc'),
        // host:port of the gRPC service.
        'grpc_host' => env('INVENTORY_GRPC_HOST', 'inventory-service:5001'),
        // Deadline for every call. Past it the user gets 503 instead of waiting.
        'timeout_ms' => (int) env('INVENTORY_TIMEOUT_MS', 2000),
        // Only for the fake driver: simulate the service being down.
        'fake_down' => (bool) env('INVENTORY_FAKE_DOWN', false),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
