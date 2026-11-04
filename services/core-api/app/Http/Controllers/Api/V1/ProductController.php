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

    /**
     * List products
     *
     * Newest first, paginated. Stock is read from the inventory service in **one call for the whole page**.
     * If the inventory service is down the list still works and `stock.status` is `unavailable`.
     *
     * @group Catalogue
     *
     * @unauthenticated
     *
     * @queryParam category_id integer Only products of this category. Example: 1
     * @queryParam search string Search in the product name. Example: jacket
     * @queryParam per_page integer Between 1 and 50 (default 15). Example: 2
     * @queryParam page integer Page number (default 1). Example: 1
     *
     * @response 200 {"data": [{"id": 7, "name": "Winter Jacket", "description": "Water-resistant jacket with hood.", "price": "89.00", "image_url": null, "category": {"id": 3, "name": "Clothing", "slug": "clothing"}, "stock": {"quantity": 8, "status": "in_stock"}, "created_at": "2026-11-04T19:50:03+00:00"}, {"id": 6, "name": "Cotton T-Shirt", "description": "100% cotton, regular fit.", "price": "12.00", "image_url": null, "category": {"id": 3, "name": "Clothing", "slug": "clothing"}, "stock": {"quantity": 100, "status": "in_stock"}, "created_at": "2026-11-04T19:50:03+00:00"}], "links": {"first": "http://localhost:8000/api/v1/products?per_page=2&page=1", "last": "http://localhost:8000/api/v1/products?per_page=2&page=4", "prev": null, "next": "http://localhost:8000/api/v1/products?per_page=2&page=2"}, "meta": {"current_page": 1, "from": 1, "last_page": 4, "path": "http://localhost:8000/api/v1/products", "per_page": 2, "to": 2, "total": 8}}
     * @response 422 scenario="Bad filters" {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {"per_page": ["The per page field must not be greater than 50."]}}}
     */
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

    /**
     * Product details
     *
     * The quantity is asked from the inventory service at request time.
     * `stock.status`: `in_stock`, `out_of_stock`, or `unavailable` (inventory service down, `quantity` is null).
     *
     * @group Catalogue
     *
     * @unauthenticated
     *
     * @urlParam product integer required The product id. Example: 1
     *
     * @response 200 scenario="Found" {"data": {"id": 8, "name": "Gaming Mouse", "description": "RGB mouse", "price": "25.50", "image_url": "http://localhost:8000/storage/products/SizurDJW4OgLiAJsDCvmDcSQbpIPE0mdLif8Yjlh.png", "category": {"id": 1, "name": "Electronics", "slug": "electronics"}, "stock": {"quantity": 5, "status": "in_stock"}, "created_at": "2026-11-04T19:51:54+00:00"}}
     * @response 200 scenario="Inventory service down" {"data": {"id": 8, "name": "Gaming Mouse", "description": "RGB mouse", "price": "25.50", "image_url": null, "category": {"id": 1, "name": "Electronics", "slug": "electronics"}, "stock": {"quantity": null, "status": "unavailable"}, "created_at": "2026-11-04T19:51:54+00:00"}}
     * @response 404 {"error": {"code": "NOT_FOUND", "message": "Product not found.", "details": {}}}
     */
    public function show(Product $product): ProductResource
    {
        $product->load('category');

        $quantity = $this->stockOrNull(fn () => $this->inventory->getStock($product->id));

        return (new ProductResource($product))->withStock($quantity);
    }

    /**
     * Create a product
     *
     * **Admin only.** `multipart/form-data` with the image. The initial quantity is sent to the inventory service;
     * if that fails nothing is saved (no product row, no image) and 503 is returned.
     *
     * @group Administration
     *
     * @authenticated
     *
     * @bodyParam category_id integer required An existing category. Example: 1
     * @bodyParam name string required Example: Gaming Mouse
     * @bodyParam description string Example: RGB mouse
     * @bodyParam price number required Greater than 0, up to 2 decimals. Example: 25.50
     * @bodyParam quantity integer required Initial stock (0 or more). Example: 5
     * @bodyParam image file required jpg, jpeg, png or webp, max 2 MB. SVG is refused.
     *
     * @response 201 {"data": {"id": 8, "name": "Gaming Mouse", "description": "RGB mouse", "price": "25.50", "image_url": "http://localhost:8000/storage/products/SizurDJW4OgLiAJsDCvmDcSQbpIPE0mdLif8Yjlh.png", "category": {"id": 1, "name": "Electronics", "slug": "electronics"}, "stock": {"quantity": 5, "status": "in_stock"}, "created_at": "2026-11-04T19:51:54+00:00"}}
     * @response 403 scenario="Customer token" {"error": {"code": "FORBIDDEN", "message": "This action is reserved for administrators.", "details": {}}}
     * @response 422 scenario="Not an image" {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {"image": ["The image field must be an image."]}}}
     * @response 503 scenario="Inventory service down" {"error": {"code": "INVENTORY_UNAVAILABLE", "message": "The inventory service is not available right now. Please try again later.", "details": {}}}
     */
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

    /**
     * Set product stock
     *
     * **Admin only.** Sets the absolute quantity in the inventory service.
     *
     * @group Administration
     *
     * @authenticated
     *
     * @urlParam product integer required The product id. Example: 1
     *
     * @bodyParam quantity integer required 0 or more. Example: 20
     *
     * @response 200 {"data": {"id": 1, "name": "Wireless Headphones", "description": "Over-ear Bluetooth headphones with noise cancelling.", "price": "79.99", "image_url": null, "category": {"id": 1, "name": "Electronics", "slug": "electronics"}, "stock": {"quantity": 20, "status": "in_stock"}, "created_at": "2026-11-04T19:50:03+00:00"}}
     * @response 503 scenario="Inventory service down" {"error": {"code": "INVENTORY_UNAVAILABLE", "message": "The inventory service is not available right now. Please try again later.", "details": {}}}
     */
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
