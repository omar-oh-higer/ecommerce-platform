using Grpc.Core;
using Grpc.Net.Client;
using InventoryService.Grpc;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace InventoryService.Tests;

/// <summary>
/// "The inventory service is slow": the caller's deadline must stop the call
/// instead of letting the user wait.
/// </summary>
[Collection(nameof(InventoryCollection))]
public sealed class DeadlineTests(InventoryServiceFixture fx)
{
    [Fact]
    public async Task A_slow_service_is_cut_off_by_the_client_deadline()
    {
        await using var slowService = new WebApplicationFactory<Program>().WithWebHostBuilder(host =>
        {
            host.UseSetting("ConnectionStrings:Inventory", fx.ConnectionString);
            host.UseSetting("Inventory:SimulatedDelayMs", "5000");
        });
        using var channel = GrpcChannel.ForAddress(slowService.Server.BaseAddress, new GrpcChannelOptions
        {
            HttpHandler = slowService.Server.CreateHandler(),
        });
        var client = new Inventory.InventoryClient(channel);

        var started = DateTime.UtcNow;
        var error = await Assert.ThrowsAsync<RpcException>(() => client.GetStockAsync(
            new GetStockRequest { ProductId = fx.NewProductId() },
            deadline: DateTime.UtcNow.AddMilliseconds(300)).ResponseAsync);

        // What matters: the call fails at the deadline instead of waiting 5 s for the slow service.
        // (With the in-memory TestServer the client aborts the request at the deadline, so the
        // status it reports varies: DEADLINE_EXCEEDED, CANCELLED or INTERNAL. Over a real network
        // the PHP client reports DEADLINE_EXCEEDED — covered by core-api's GrpcInventoryClientTest.)
        Assert.NotEqual(StatusCode.OK, error.StatusCode);
        Assert.True(DateTime.UtcNow - started < TimeSpan.FromSeconds(2), "the caller did not wait for the 5 s delay");
    }
}
