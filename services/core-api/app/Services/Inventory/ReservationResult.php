<?php

namespace App\Services\Inventory;

final class ReservationResult
{
    /**
     * @param  array<int, int>  $unavailable  product id => quantity still available (only when rejected)
     */
    public function __construct(
        public readonly bool $success,
        public readonly string $message = '',
        public readonly array $unavailable = [],
    ) {}

    public static function accepted(): self
    {
        return new self(true, 'Reserved.');
    }

    /**
     * @param  array<int, int>  $unavailable
     */
    public static function rejected(array $unavailable): self
    {
        return new self(false, 'Not enough stock for some items.', $unavailable);
    }
}
