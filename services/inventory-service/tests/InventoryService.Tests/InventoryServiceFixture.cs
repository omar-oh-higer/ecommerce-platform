using Grpc.Net.Client;
using InventoryService.Grpc;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Testcontainers.PostgreSql;

namespace InventoryService.Tests;

/// <summary>
/// Starts a real PostgreSQL in Docker (Testcontainers) and the inventory service in memory,
/// then gives tests a real gRPC client. Shared by all tests in the collection.
/// </summary>
public sealed class InventoryServiceFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine")
        .WithDatabase("inventory")
        .WithUsername("inventory")
        .WithPassword("secret")
        .Build();

    private WebApplicationFactory<Program>? _factory;
    private GrpcChannel? _channel;
    private long _nextProductId = 1_000;

    public Inventory.InventoryClient Client { get; private set; } = null!;

    public string ConnectionString => _postgres.GetConnectionString();

    /// <summary>Each test uses its own product ids so tests never affect each other.</summary>
    public long NewProductId() => Interlocked.Increment(ref _nextProductId);

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(host =>
        {
            host.UseSetting("ConnectionStrings:Inventory", _postgres.GetConnectionString());
            host.UseSetting("Database:MigrateOnStartup", "true");
        });

        _channel = GrpcChannel.ForAddress(_factory.Server.BaseAddress, new GrpcChannelOptions
        {
            HttpHandler = _factory.Server.CreateHandler(),
        });

        Client = new Inventory.InventoryClient(_channel);
    }

    public async Task DisposeAsync()
    {
        _channel?.Dispose();
        if (_factory is not null)
        {
            await _factory.DisposeAsync();
        }

        await _postgres.DisposeAsync();
    }
}

[CollectionDefinition(nameof(InventoryCollection))]
public sealed class InventoryCollection : ICollectionFixture<InventoryServiceFixture>;
