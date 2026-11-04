<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use App\Services\Inventory\FakeInventoryClient;
use App\Services\Inventory\InventoryClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    private InventoryClient $inventory;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->inventory = app(InventoryClient::class);
    }

    private function inventoryIsDown(): void
    {
        $this->app->instance(InventoryClient::class, new FakeInventoryClient(app('cache')->store(), down: true));
    }

    private function adminToken(): string
    {
        return auth('api')->login(User::factory()->admin()->create());
    }

    private function customerToken(): string
    {
        return auth('api')->login(User::factory()->create());
    }

    private function productPayload(array $overrides = []): array
    {
        return array_merge([
            'category_id' => Category::factory()->create()->id,
            'name' => 'Wireless Headphones',
            'description' => 'Noise cancelling.',
            'price' => '79.99',
            'quantity' => 10,
            'image' => UploadedFile::fake()->image('headphones.jpg', 600, 600),
        ], $overrides);
    }

    // ---- Browse -------------------------------------------------------------

    public function test_products_are_listed_with_pagination_and_stock(): void
    {
        $products = Product::factory()->count(20)->create();
        $this->inventory->setStock($products->last()->id, 7);

        $response = $this->getJson('/api/v1/products?per_page=5')
            ->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('meta.total', 20)
            ->assertJsonPath('meta.per_page', 5)
            ->assertJsonPath('meta.last_page', 4)
            ->assertJsonStructure([
                'data' => [['id', 'name', 'description', 'price', 'image_url', 'category' => ['id', 'name', 'slug'], 'stock' => ['quantity', 'status'], 'created_at']],
                'links' => ['first', 'last', 'prev', 'next'],
                'meta' => ['current_page', 'last_page', 'per_page', 'total'],
            ]);

        // Newest first; the newest one has 7 in stock.
        $response->assertJsonPath('data.0.id', $products->last()->id)
            ->assertJsonPath('data.0.stock.quantity', 7)
            ->assertJsonPath('data.0.stock.status', 'in_stock')
            ->assertJsonPath('data.1.stock.status', 'out_of_stock');
    }

    public function test_products_can_be_filtered_by_category(): void
    {
        $books = Category::factory()->create();
        Product::factory()->count(3)->for($books)->create();
        Product::factory()->count(4)->create();

        $this->getJson("/api/v1/products?category_id={$books->id}")
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.category.id', $books->id);
    }

    public function test_products_can_be_searched_by_name(): void
    {
        Product::factory()->create(['name' => 'Red Winter Jacket']);
        Product::factory()->create(['name' => 'Blue T-Shirt']);

        $this->getJson('/api/v1/products?search=jacket')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Red Winter Jacket');
    }

    public function test_listing_rejects_bad_filters(): void
    {
        $this->getJson('/api/v1/products?per_page=500&category_id=999')
            ->assertUnprocessable()
            ->assertJsonStructure(['error' => ['details' => ['per_page', 'category_id']]]);
    }

    public function test_product_details_include_stock_from_inventory(): void
    {
        $product = Product::factory()->create(['price' => '19.90']);
        $this->inventory->setStock($product->id, 3);

        $this->getJson("/api/v1/products/{$product->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $product->id)
            ->assertJsonPath('data.price', '19.90')
            ->assertJsonPath('data.stock.quantity', 3)
            ->assertJsonPath('data.stock.status', 'in_stock');
    }

    public function test_unknown_product_returns_clean_404(): void
    {
        $this->getJson('/api/v1/products/99999')
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND')
            ->assertJsonPath('error.message', 'Product not found.');
    }

    public function test_catalogue_still_works_when_inventory_is_down(): void
    {
        $product = Product::factory()->create();
        $this->inventoryIsDown();

        $this->getJson("/api/v1/products/{$product->id}")
            ->assertOk()
            ->assertJsonPath('data.stock.quantity', null)
            ->assertJsonPath('data.stock.status', 'unavailable');

        $this->getJson('/api/v1/products')
            ->assertOk()
            ->assertJsonPath('data.0.stock.status', 'unavailable');
    }

    public function test_categories_are_listed_with_product_counts(): void
    {
        $category = Category::factory()->create(['name' => 'Books']);
        Product::factory()->count(2)->for($category)->create();

        $this->getJson('/api/v1/categories')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Books')
            ->assertJsonPath('data.0.products_count', 2);
    }

    // ---- Create (admin) -----------------------------------------------------

    public function test_admin_can_create_a_product_with_image_and_stock(): void
    {
        $response = $this->withToken($this->adminToken())
            ->postJson('/api/v1/products', $this->productPayload())
            ->assertCreated()
            ->assertJsonPath('data.name', 'Wireless Headphones')
            ->assertJsonPath('data.price', '79.99')
            ->assertJsonPath('data.stock.quantity', 10);

        $product = Product::firstOrFail();
        Storage::disk('public')->assertExists($product->image_path);
        $this->assertStringNotContainsString('headphones', $product->image_path, 'stored under a random name');
        $this->assertStringEndsWith($product->image_path, $response->json('data.image_url'));
        $this->assertSame(10, $this->inventory->getStock($product->id));
    }

    public function test_customer_cannot_create_products(): void
    {
        $this->withToken($this->customerToken())
            ->postJson('/api/v1/products', $this->productPayload())
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');

        $this->assertDatabaseCount('products', 0);
    }

    public function test_guest_cannot_create_products(): void
    {
        $this->postJson('/api/v1/products', $this->productPayload())->assertUnauthorized();
    }

    public function test_product_requires_a_real_image(): void
    {
        $this->withToken($this->adminToken())
            ->postJson('/api/v1/products', $this->productPayload([
                'image' => UploadedFile::fake()->create('script.php', 10, 'application/x-php'),
                'price' => '-5',
            ]))
            ->assertUnprocessable()
            ->assertJsonStructure(['error' => ['details' => ['image', 'price']]]);
    }

    public function test_svg_images_are_rejected(): void
    {
        $this->withToken($this->adminToken())
            ->postJson('/api/v1/products', $this->productPayload([
                'image' => UploadedFile::fake()->createWithContent('logo.svg', '<svg><script>alert(1)</script></svg>'),
            ]))
            ->assertUnprocessable()
            ->assertJsonStructure(['error' => ['details' => ['image']]]);
    }

    public function test_nothing_is_saved_when_inventory_is_down_during_create(): void
    {
        $token = $this->adminToken();
        $payload = $this->productPayload();
        $this->inventoryIsDown();

        $this->withToken($token)
            ->postJson('/api/v1/products', $payload)
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'INVENTORY_UNAVAILABLE');

        $this->assertDatabaseCount('products', 0);
        $this->assertEmpty(Storage::disk('public')->allFiles(), 'uploaded image was removed');
    }

    // ---- Stock (admin) ------------------------------------------------------

    public function test_admin_can_update_stock(): void
    {
        $product = Product::factory()->create();

        $this->withToken($this->adminToken())
            ->patchJson("/api/v1/products/{$product->id}/stock", ['quantity' => 42])
            ->assertOk()
            ->assertJsonPath('data.stock.quantity', 42);

        $this->assertSame(42, $this->inventory->getStock($product->id));
    }

    public function test_customer_cannot_update_stock(): void
    {
        $product = Product::factory()->create();

        $this->withToken($this->customerToken())
            ->patchJson("/api/v1/products/{$product->id}/stock", ['quantity' => 42])
            ->assertForbidden();
    }

    public function test_admin_can_create_a_category_and_customer_cannot(): void
    {
        $this->withToken($this->customerToken())
            ->postJson('/api/v1/categories', ['name' => 'Toys'])
            ->assertForbidden();

        $this->app['auth']->forgetGuards();

        $this->withToken($this->adminToken())
            ->postJson('/api/v1/categories', ['name' => 'Toys & Games'])
            ->assertCreated()
            ->assertJsonPath('data.slug', 'toys-games');
    }
}
