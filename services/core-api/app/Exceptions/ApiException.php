<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * A business error that should reach the client as-is, in the unified error format.
 *
 * Example: throw new ApiException('INSUFFICIENT_STOCK', 'Not enough stock.', 409, ['items' => [...]]);
 */
class ApiException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 400,
        public readonly array $details = [],
    ) {
        parent::__construct($message);
    }
}
