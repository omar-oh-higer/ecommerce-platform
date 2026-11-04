using Grpc.Core;
using InventoryService.Grpc;

namespace InventoryService.Tests;

[Collection(nameof(InventoryCollection))]
public sealed class InventoryGrpcTests(InventoryServiceFixture fx)
{
    private Inventory.InventoryClient Client => fx.Client;

    private async Task<long> ProductWithStock(int quantity)
    {
        var id = fx.NewProductId();
        await Client.SetStockAsync(new SetStockRequest { ProductId = id, Quantity = quantity });
        return id;
    }

    private static ReserveStockRequest Reserve(string reservationId, params (long ProductId, int Quantity)[] items)
    {
        var request = new ReserveStockRequest { ReservationId = reservationId };
        request.Items.AddRange(items.Select(i => new StockItem { ProductId = i.ProductId, Quantity = i.Quantity }));
        return request;
    }

    private async Task<int> StockOf(long productId) =>
        (await Client.GetStockAsync(new GetStockRequest { ProductId = productId })).Quantity;

    // ---- 1) Get quantity ------------------------------------------------------------

    [Fact]
    public async Task Get_stock_returns_the_quantity_and_zero_for_unknown_products()
    {
        var product = await ProductWithStock(7);

        Assert.Equal(7, await StockOf(product));
        Assert.Equal(0, await StockOf(fx.NewProductId()));
    }

    [Fact]
    public async Task Get_stock_batch_returns_every_requested_product()
    {
        var a = await ProductWithStock(3);
        var b = await ProductWithStock(0);
        var unknown = fx.NewProductId();

        var reply = await Client.GetStockBatchAsync(new GetStockBatchRequest { ProductIds = { a, b, unknown } });

        var stock = reply.Items.ToDictionary(i => i.ProductId, i => i.Quantity);
        Assert.Equal(3, stock[a]);
        Assert.Equal(0, stock[b]);
        Assert.Equal(0, stock[unknown]);
    }

    [Fact]
    public async Task Set_stock_overwrites_the_quantity()
    {
        var product = await ProductWithStock(5);

        await Client.SetStockAsync(new SetStockRequest { ProductId = product, Quantity = 42 });

        Assert.Equal(42, await StockOf(product));
    }

    // ---- 2) Reserve quantity ----------------------------------------------------------

    [Fact]
    public async Task Reserve_takes_every_item_in_one_call()
    {
        var mouse = await ProductWithStock(10);
        var cable = await ProductWithStock(5);

        var reply = await Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (mouse, 2), (cable, 3)));

        Assert.True(reply.Success);
        Assert.Equal(8, await StockOf(mouse));
        Assert.Equal(2, await StockOf(cable));
    }

    [Fact]
    public async Task Reserve_is_all_or_nothing_and_reports_unavailable_items()
    {
        var plenty = await ProductWithStock(10);
        var scarce = await ProductWithStock(1);

        var reply = await Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (plenty, 2), (scarce, 3)));

        Assert.False(reply.Success);
        var missing = Assert.Single(reply.UnavailableItems);
        Assert.Equal(scarce, missing.ProductId);
        Assert.Equal(1, missing.Quantity);

        // Nothing was taken, not even the product that had enough stock.
        Assert.Equal(10, await StockOf(plenty));
        Assert.Equal(1, await StockOf(scarce));
    }

    [Fact]
    public async Task Reserving_twice_with_the_same_id_takes_the_stock_once()
    {
        var product = await ProductWithStock(5);
        var request = Reserve(Guid.NewGuid().ToString(), (product, 2));

        var first = await Client.ReserveStockAsync(request);
        var second = await Client.ReserveStockAsync(request);

        Assert.True(first.Success);
        Assert.True(second.Success);
        Assert.Equal(3, await StockOf(product));
    }

    /// <summary>
    /// Required proof (slide 13): many orders at the same moment on the last unit → only ONE succeeds.
    /// </summary>
    [Fact]
    public async Task Race_condition_only_one_of_many_concurrent_orders_gets_the_last_unit()
    {
        var product = await ProductWithStock(1);

        var replies = await Task.WhenAll(Enumerable.Range(0, 25).Select(_ =>
            Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (product, 1))).ResponseAsync));

        Assert.Equal(1, replies.Count(r => r.Success));
        Assert.Equal(24, replies.Count(r => !r.Success));
        Assert.Equal(0, await StockOf(product)); // never negative
    }

    [Fact]
    public async Task Race_condition_with_more_stock_never_oversells()
    {
        var product = await ProductWithStock(5);

        var replies = await Task.WhenAll(Enumerable.Range(0, 30).Select(_ =>
            Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (product, 1))).ResponseAsync));

        Assert.Equal(5, replies.Count(r => r.Success));
        Assert.Equal(0, await StockOf(product));
    }

    [Fact]
    public async Task Concurrent_orders_on_the_same_products_in_different_order_do_not_deadlock()
    {
        var a = await ProductWithStock(100);
        var b = await ProductWithStock(100);

        var replies = await Task.WhenAll(Enumerable.Range(0, 20).Select(i =>
            Client.ReserveStockAsync(i % 2 == 0
                ? Reserve(Guid.NewGuid().ToString(), (a, 1), (b, 1))
                : Reserve(Guid.NewGuid().ToString(), (b, 1), (a, 1))).ResponseAsync));

        Assert.All(replies, r => Assert.True(r.Success));
        Assert.Equal(80, await StockOf(a));
        Assert.Equal(80, await StockOf(b));
    }

    // ---- 3) Release quantity -------------------------------------------------------------

    [Fact]
    public async Task Release_gives_the_stock_back_only_once()
    {
        var product = await ProductWithStock(5);
        var reservationId = Guid.NewGuid().ToString();
        await Client.ReserveStockAsync(Reserve(reservationId, (product, 3)));
        Assert.Equal(2, await StockOf(product));

        var first = await Client.ReleaseStockAsync(new ReleaseStockRequest { ReservationId = reservationId });
        var second = await Client.ReleaseStockAsync(new ReleaseStockRequest { ReservationId = reservationId });

        Assert.True(first.Success);
        Assert.True(second.Success);
        Assert.Equal("Already released.", second.Message);
        Assert.Equal(5, await StockOf(product));
    }

    [Fact]
    public async Task Concurrent_releases_of_the_same_reservation_return_the_stock_once()
    {
        var product = await ProductWithStock(5);
        var reservationId = Guid.NewGuid().ToString();
        await Client.ReserveStockAsync(Reserve(reservationId, (product, 4)));

        await Task.WhenAll(Enumerable.Range(0, 10).Select(_ =>
            Client.ReleaseStockAsync(new ReleaseStockRequest { ReservationId = reservationId }).ResponseAsync));

        Assert.Equal(5, await StockOf(product));
    }

    [Fact]
    public async Task Releasing_an_unknown_reservation_reports_it()
    {
        var reply = await Client.ReleaseStockAsync(new ReleaseStockRequest { ReservationId = Guid.NewGuid().ToString() });

        Assert.False(reply.Success);
        Assert.Equal("Reservation not found.", reply.Message);
    }

    // ---- Input validation -------------------------------------------------------------------

    [Fact]
    public async Task Invalid_input_is_rejected_with_invalid_argument()
    {
        var product = await ProductWithStock(5);

        async Task AssertInvalid(Func<Task> call)
        {
            var error = await Assert.ThrowsAsync<RpcException>(call);
            Assert.Equal(StatusCode.InvalidArgument, error.StatusCode);
        }

        await AssertInvalid(() => Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString())).ResponseAsync);                        // no items
        await AssertInvalid(() => Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (product, 0))).ResponseAsync);          // quantity 0
        await AssertInvalid(() => Client.ReserveStockAsync(Reserve(Guid.NewGuid().ToString(), (product, 1), (product, 1))).ResponseAsync); // duplicate
        await AssertInvalid(() => Client.ReserveStockAsync(Reserve("", (product, 1))).ResponseAsync);                                  // no id
        await AssertInvalid(() => Client.SetStockAsync(new SetStockRequest { ProductId = product, Quantity = -1 }).ResponseAsync);
        await AssertInvalid(() => Client.GetStockAsync(new GetStockRequest { ProductId = 0 }).ResponseAsync);

        Assert.Equal(5, await StockOf(product));
    }
}
