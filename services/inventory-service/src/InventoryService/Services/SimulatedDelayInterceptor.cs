using Grpc.Core;
using Grpc.Core.Interceptors;

namespace InventoryService.Services;

/// <summary>
/// DEMO ONLY: makes every call slow to show the caller's deadline in action.
/// Off by default. Enable with the setting Inventory__SimulatedDelayMs (e.g. 5000):
///
///   INVENTORY_SIMULATED_DELAY_MS=5000 docker compose up -d inventory-service
///
/// The delay stops as soon as the client's deadline expires (DEADLINE_EXCEEDED).
/// </summary>
public sealed class SimulatedDelayInterceptor(IConfiguration config, ILogger<SimulatedDelayInterceptor> logger) : Interceptor
{
    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(
        TRequest request,
        ServerCallContext context,
        UnaryServerMethod<TRequest, TResponse> continuation)
    {
        var delayMs = config.GetValue("Inventory:SimulatedDelayMs", 0);

        if (delayMs > 0)
        {
            logger.LogWarning("Simulated delay of {Delay} ms on {Method}", delayMs, context.Method);
            await Task.Delay(delayMs, context.CancellationToken);
        }

        return await continuation(request, context);
    }
}
