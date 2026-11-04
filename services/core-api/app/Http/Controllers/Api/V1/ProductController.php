<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Products\ListProductsRequest;
use App\Http\Requests\Products\StoreProductRequest;
use App\Http\Requests\Products\UpdateStockRequest;
use App\Http\Resources\ProductCollection;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Services\Inventory\InventoryClient;
use App\Services\Inventory\InventoryUnavailableException;
use App\Services\ProductService;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function __construct(private readonly InventoryClient $inventory) {}

    /** GET /api/v1/products?category_id=&search=&per_page=&page= */
    public function index(ListProductsRequest $request): ProductCollection
    {
        $products = Product::query()
            ->with('category')
            ->when($request->integer('category_id'), fn ($q, $id) => $q->where('category_id', $id))
            ->when($request->string('search')->trim()->value(), fn ($q, $term) => $q->where('name', 'like', '%'.addcslashes($term, '%_\\').'%'))
            ->latest('id')
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        // One inventory call for the whole page. If inventory is down the list still works.
        $stock = $this->stockOrNull(fn () => $this->inventory->getStockBatch($products->pluck('id')->all()));

        return (new ProductCollection($products))->withStock($stock);
    }

    /** GET /api/v1/products/{product} — details + quantity asked from the inventory service. */
    public function show(Product $product): ProductResource
    {
        $product->load('category');

        $quantity = $this->stockOrNull(fn () => $this->inventory->getStock($product->id));

        return (new ProductResource($product))->withStock($quantity);
    }

    /** POST /api/v1/products (admin, multipart/form-data) */
    public function store(StoreProductRequest $request, ProductService $service): JsonResponse
    {
        $product = $service->create(
            $request->safe()->only(['category_id', 'name', 'description', 'price']),
            $request->file('image'),
            $request->integer('quantity'),
        );

        return (new ProductResource($product->load('category')))
            ->withStock($request->integer('quantity'))
            ->response()
            ->setStatusCode(201);
    }

    /** PATCH /api/v1/products/{product}/stock (admin) */
    public function updateStock(UpdateStockRequest $request, Product $product): ProductResource
    {
        $quantity = $this->inventory->setStock($product->id, $request->integer('quantity'));

        return (new ProductResource($product->load('category')))->withStock($quantity);
    }

    /**
     * Reading stock must never break the catalogue: when the inventory service is down
     * the products are still shown, with stock status "unavailable".
     *
     * @template T
     *
     * @param  callable(): T  $read
     * @return T|null
     */
    private function stockOrNull(callable $read): mixed
    {
        try {
            return $read();
        } catch (InventoryUnavailableException) {
            return null;
        }
    }
}
