using Grpc.Core;
using InventoryService.Data;
using InventoryService.Grpc;

namespace InventoryService.Services;

/// <summary>
/// Implements the Inventory service from proto/inventory.proto.
/// Invalid input → INVALID_ARGUMENT. Every call honours the client's deadline
/// (context.CancellationToken is cancelled when the deadline expires).
/// </summary>
public sealed class InventoryGrpcService(InventoryStore store) : Inventory.InventoryBase
{
    private const int MaxItems = 100;

    public override async Task<StockReply> GetStock(GetStockRequest request, ServerCallContext context)
    {
        RequirePositive(request.ProductId, "product_id");

        var quantity = await store.GetStockAsync(request.ProductId, context.CancellationToken);

        return new StockReply { ProductId = request.ProductId, Quantity = quantity };
    }

    public override async Task<GetStockBatchReply> GetStockBatch(GetStockBatchRequest request, ServerCallContext context)
    {
        if (request.ProductIds.Count > 500)
        {
            throw Invalid("product_ids: at most 500 ids per call.");
        }

        foreach (var id in request.ProductIds)
        {
            RequirePositive(id, "product_ids");
        }

        var stock = await store.GetStockBatchAsync(request.ProductIds, context.CancellationToken);

        var reply = new GetStockBatchReply();
        reply.Items.AddRange(stock.Select(s => new StockReply { ProductId = s.Key, Quantity = s.Value }));

        return reply;
    }

    public override async Task<StockReply> SetStock(SetStockRequest request, ServerCallContext context)
    {
        RequirePositive(request.ProductId, "product_id");
        if (request.Quantity < 0)
        {
            throw Invalid("quantity must be 0 or more.");
        }

        var quantity = await store.SetStockAsync(request.ProductId, request.Quantity, context.CancellationToken);

        return new StockReply { ProductId = request.ProductId, Quantity = quantity };
    }

    public override async Task<ReserveStockReply> ReserveStock(ReserveStockRequest request, ServerCallContext context)
    {
        RequireReservationId(request.ReservationId);

        if (request.Items.Count is 0 or > MaxItems)
        {
            throw Invalid($"items: between 1 and {MaxItems} items.");
        }

        var items = new Dictionary<long, int>();
        foreach (var item in request.Items)
        {
            RequirePositive(item.ProductId, "items.product_id");
            if (item.Quantity <= 0)
            {
                throw Invalid("items.quantity must be greater than 0.");
            }

            if (!items.TryAdd(item.ProductId, item.Quantity))
            {
                throw Invalid($"items: product {item.ProductId} appears more than once.");
            }
        }

        var result = await store.ReserveAsync(request.ReservationId, items, context.CancellationToken);

        var reply = new ReserveStockReply { Success = result.Success, Message = result.Message };
        reply.UnavailableItems.AddRange(result.Unavailable.Select(u => new Grpc.StockItem { ProductId = u.Key, Quantity = u.Value }));

        return reply;
    }

    public override async Task<ReleaseStockReply> ReleaseStock(ReleaseStockRequest request, ServerCallContext context)
    {
        RequireReservationId(request.ReservationId);

        var result = await store.ReleaseAsync(request.ReservationId, context.CancellationToken);

        return new ReleaseStockReply { Success = result.Success, Message = result.Message };
    }

    private static void RequirePositive(long id, string field)
    {
        if (id <= 0)
        {
            throw Invalid($"{field} must be greater than 0.");
        }
    }

    private static void RequireReservationId(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Length > 64)
        {
            throw Invalid("reservation_id is required (max 64 characters).");
        }
    }

    private static RpcException Invalid(string message) => new(new Status(StatusCode.InvalidArgument, message));
}
