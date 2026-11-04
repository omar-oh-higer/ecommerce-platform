using InventoryService.Data;
using InventoryService.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddGrpc(options =>
{
    options.Interceptors.Add<ErrorInterceptor>();          // outermost: maps every failure to a clear status
    options.Interceptors.Add<SimulatedDelayInterceptor>(); // demo only, off unless configured
    options.EnableDetailedErrors = false; // never send stack traces to clients
});
builder.Services.AddGrpcReflection(); // lets grpcurl / Postman discover the service

builder.Services.AddDbContext<InventoryDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Inventory")));

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<InventoryStore>();

builder.Services.AddHealthChecks()
    .AddDbContextCheck<InventoryDbContext>("database");

var app = builder.Build();

// Create / update the database schema on start-up.
if (app.Configuration.GetValue("Database:MigrateOnStartup", true))
{
    await using var scope = app.Services.CreateAsyncScope();
    await scope.ServiceProvider.GetRequiredService<InventoryDbContext>().Database.MigrateAsync();
}

app.MapGrpcService<InventoryGrpcService>();
app.MapGrpcReflectionService();

// Plain HTTP/1.1 health endpoint (port 8080) for the Docker health check.
app.MapHealthChecks("/health");

app.Run();

/// <summary>Exposed for WebApplicationFactory in the integration tests.</summary>
public partial class Program;
