<?php

namespace App\Http\Resources;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Product
 */
class ProductResource extends JsonResource
{
    /** Quantity from the inventory service; null when the service could not be reached. */
    private ?int $stockQuantity = null;

    private bool $stockKnown = false;

    public function withStock(?int $quantity): static
    {
        $this->stockQuantity = $quantity;
        $this->stockKnown = $quantity !== null;

        return $this;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'price' => $this->price,
            'image_url' => $this->imageUrl(),
            'category' => new CategoryResource($this->whenLoaded('category')),
            'stock' => [
                'quantity' => $this->stockQuantity,
                'status' => match (true) {
                    ! $this->stockKnown => 'unavailable',
                    $this->stockQuantity > 0 => 'in_stock',
                    default => 'out_of_stock',
                },
            ],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
