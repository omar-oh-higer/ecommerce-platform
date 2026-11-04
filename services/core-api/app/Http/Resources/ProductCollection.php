<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * A page of products, each with its stock from the inventory service.
 */
class ProductCollection extends ResourceCollection
{
    public $collects = ProductResource::class;

    /** @var array<int, int>|null product id => quantity; null when inventory is unavailable */
    private ?array $stock = null;

    /**
     * @param  array<int, int>|null  $stock
     */
    public function withStock(?array $stock): static
    {
        $this->stock = $stock;

        return $this;
    }

    public function toArray(Request $request): array
    {
        $this->collection->each(
            fn (ProductResource $product) => $product->withStock(
                $this->stock === null ? null : ($this->stock[$product->id] ?? 0)
            )
        );

        return parent::toArray($request);
    }
}
