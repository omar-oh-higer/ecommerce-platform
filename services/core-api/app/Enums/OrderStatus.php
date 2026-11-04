<?php

namespace App\Enums;

/**
 * Order life cycle:
 *
 *   pending ──► confirmed ──► shipped ──► delivered
 *      │            │
 *      └──► cancelled ◄┘
 *
 * Cancelling gives the reserved stock back to the inventory service.
 */
enum OrderStatus: string
{
    case Pending = 'pending';
    case Confirmed = 'confirmed';
    case Shipped = 'shipped';
    case Delivered = 'delivered';
    case Cancelled = 'cancelled';

    /** @return self[] the statuses this one may move to */
    public function next(): array
    {
        return match ($this) {
            self::Pending => [self::Confirmed, self::Cancelled],
            self::Confirmed => [self::Shipped, self::Cancelled],
            self::Shipped => [self::Delivered],
            self::Delivered, self::Cancelled => [],
        };
    }

    public function canMoveTo(self $status): bool
    {
        return in_array($status, $this->next(), true);
    }

    /** @return string[] */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
