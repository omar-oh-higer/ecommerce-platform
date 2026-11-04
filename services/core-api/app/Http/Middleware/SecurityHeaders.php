<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Basic security headers for every API response.
 */
class SecurityHeaders
{
    private const HEADERS = [
        // Do not let the browser guess the content type.
        'X-Content-Type-Options' => 'nosniff',
        // The API must never be shown inside a frame (clickjacking).
        'X-Frame-Options' => 'DENY',
        // A JSON API loads nothing: block every resource and every framing.
        'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'",
        // Do not send the full URL to other sites.
        'Referrer-Policy' => 'no-referrer',
        // Force HTTPS for one year once the site is served over HTTPS.
        'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
        // The API needs no camera, microphone or location.
        'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        foreach (self::HEADERS as $name => $value) {
            $response->headers->set($name, $value);
        }

        // Hide the PHP version.
        $response->headers->remove('X-Powered-By');
        if (! headers_sent()) {
            header_remove('X-Powered-By');
        }

        return $response;
    }
}
