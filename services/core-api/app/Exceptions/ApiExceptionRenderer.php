<?php

namespace App\Exceptions;

use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Turns every exception raised under /api into one JSON shape:
 *
 * {
 *   "error": {
 *     "code": "VALIDATION_FAILED",
 *     "message": "The given data was invalid.",
 *     "details": { ... }
 *   }
 * }
 */
class ApiExceptionRenderer
{
    /** Machine-readable code for each HTTP status. */
    private const CODES = [
        400 => 'BAD_REQUEST',
        401 => 'UNAUTHENTICATED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        405 => 'METHOD_NOT_ALLOWED',
        409 => 'CONFLICT',
        413 => 'PAYLOAD_TOO_LARGE',
        415 => 'UNSUPPORTED_MEDIA_TYPE',
        419 => 'SESSION_EXPIRED',
        422 => 'VALIDATION_FAILED',
        429 => 'TOO_MANY_REQUESTS',
        500 => 'SERVER_ERROR',
        503 => 'SERVICE_UNAVAILABLE',
    ];

    public static function render(Throwable $e): ?JsonResponse
    {
        // A response built on purpose somewhere else: leave it alone.
        if ($e instanceof HttpResponseException) {
            return null;
        }

        if ($e instanceof ApiException) {
            return self::json($e->status, $e->errorCode, $e->getMessage(), $e->details);
        }

        if ($e instanceof ValidationException) {
            return self::json(422, self::CODES[422], 'The given data was invalid.', $e->errors());
        }

        if ($e instanceof AuthenticationException) {
            return self::json(401, self::CODES[401], 'Authentication is required.');
        }

        // Covers 403 (authorization), 404 (missing model/route), 405, 429 (throttle), ...
        if ($e instanceof HttpExceptionInterface) {
            $status = $e->getStatusCode();
            $message = $e->getMessage() !== '' ? $e->getMessage() : self::defaultMessage($status);

            return self::json($status, self::CODES[$status] ?? 'HTTP_ERROR', $message, [], $e->getHeaders());
        }

        // Unexpected error: never leak internals unless debugging.
        $message = config('app.debug') ? $e->getMessage() : 'Something went wrong on our side.';

        return self::json(500, self::CODES[500], $message);
    }

    private static function json(int $status, string $code, string $message, array $details = [], array $headers = []): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => (object) $details,
            ],
        ], $status, $headers);
    }

    private static function defaultMessage(int $status): string
    {
        return match ($status) {
            403 => 'You are not allowed to perform this action.',
            404 => 'The requested resource was not found.',
            405 => 'This method is not allowed for this endpoint.',
            429 => 'Too many requests. Please try again later.',
            default => 'The request could not be completed.',
        };
    }
}
