<?php

namespace App\Http\Resources;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Order
 */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $isAdmin = (bool) $request->user()?->isAdmin();

        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'total' => $this->total,
            'items_count' => $this->whenCounted('items'),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            // Customer details are only shown to administrators.
            'customer' => $this->when($isAdmin && $this->relationLoaded('user'), fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'email' => $this->user->email,
            ]),
            // Cancelled orders only: "done" = stock is back in the inventory service,
            // "pending" = the inventory service was down; a background job returns it as soon as it is back.
            'stock_return' => $this->when(
                $this->status === OrderStatus::Cancelled,
                fn () => $this->stock_released_at ? 'done' : 'pending',
            ),
            // Helps the admin screen show only the buttons that are allowed.
            'next_statuses' => $this->when($isAdmin, fn () => array_column($this->status->next(), 'value')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
