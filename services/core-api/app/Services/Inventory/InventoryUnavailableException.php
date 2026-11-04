<?php

namespace App\Services\Inventory;

use App\Exceptions\ApiException;
use Throwable;

/**
 * The inventory service is down or did not answer before the deadline.
 * Rendered as 503 INVENTORY_UNAVAILABLE in the unified error format.
 * The technical cause is kept as the previous exception: it appears in the logs, never in the response.
 */
class InventoryUnavailableException extends ApiException
{
    public function __construct(?Throwable $previous = null)
    {
        parent::__construct(
            'INVENTORY_UNAVAILABLE',
            'The inventory service is not available right now. Please try again later.',
            503,
            [],
            $previous,
        );
    }
}
