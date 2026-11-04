<?php

namespace App\Services;

use App\Models\Product;
use App\Services\Inventory\InventoryClient;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

class ProductService
{
    public function __construct(private readonly InventoryClient $inventory) {}

    /**
     * Create a product with its image and initial stock.
     * All or nothing: if the inventory service fails, the product row and the image are removed.
     *
     * @param  array{category_id:int, name:string, description:?string, price:string|float}  $data
     */
    public function create(array $data, UploadedFile $image, int $quantity): Product
    {
        // Random file name: never trust the name sent by the client.
        $path = $image->store('products', 'public');

        try {
            return DB::transaction(function () use ($data, $path, $quantity) {
                $product = Product::create([...$data, 'image_path' => $path]);

                $this->inventory->setStock($product->id, $quantity);

                return $product;
            });
        } catch (Throwable $e) {
            Storage::disk('public')->delete($path);

            throw $e;
        }
    }
}
