using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace InventoryService.Data;

public sealed record ReserveResult(bool Success, string Message, IReadOnlyDictionary<long, int> Unavailable)
{
    public static ReserveResult Accepted() => new(true, "Reserved.", new Dictionary<long, int>());

    public static ReserveResult AlreadyReserved() => new(true, "Already reserved.", new Dictionary<long, int>());

    public static ReserveResult Rejected(IReadOnlyDictionary<long, int> unavailable) =>
        new(false, "Not enough stock for some items.", unavailable);
}

public sealed record ReleaseResult(bool Success, string Message);

/// <summary>
/// All inventory rules. The gRPC layer only validates input and maps messages.
///
/// Race conditions are prevented by the database, not by application code:
/// every decrement is ONE conditional UPDATE ("quantity = quantity - n WHERE quantity >= n").
/// PostgreSQL locks the row while updating it and re-checks the condition on the latest
/// committed value, so when many orders hit the last unit at the same moment only one
/// UPDATE matches; the others affect 0 rows and are rejected.
/// </summary>
public sealed class InventoryStore(InventoryDbContext db, TimeProvider clock, ILogger<InventoryStore> logger)
{
    public async Task<int> GetStockAsync(long productId, CancellationToken ct)
    {
        return await db.StockItems.AsNoTracking()
            .Where(s => s.ProductId == productId)
            .Select(s => (int?)s.Quantity)
            .FirstOrDefaultAsync(ct) ?? 0;
    }

    /// <summary>Missing products are returned with quantity 0.</summary>
    public async Task<IReadOnlyDictionary<long, int>> GetStockBatchAsync(IReadOnlyCollection<long> productIds, CancellationToken ct)
    {
        var found = await db.StockItems.AsNoTracking()
            .Where(s => productIds.Contains(s.ProductId))
            .ToDictionaryAsync(s => s.ProductId, s => s.Quantity, ct);

        return productIds.Distinct().ToDictionary(id => id, id => found.GetValueOrDefault(id, 0));
    }

    /// <summary>Set the absolute quantity (insert or update).</summary>
    public async Task<int> SetStockAsync(long productId, int quantity, CancellationToken ct)
    {
        var now = clock.GetUtcNow();

        await db.Database.ExecuteSqlAsync($"""
            INSERT INTO stock_items (product_id, quantity, updated_at)
            VALUES ({productId}, {quantity}, {now})
            ON CONFLICT (product_id) DO UPDATE
            SET quantity = EXCLUDED.quantity, updated_at = EXCLUDED.updated_at
            """, ct);

        logger.LogInformation("Stock of product {ProductId} set to {Quantity}", productId, quantity);

        return quantity;
    }

    /// <summary>
    /// Reserve every item in one transaction: all or nothing.
    /// Idempotent: the same reservation id never reserves twice.
    /// </summary>
    public async Task<ReserveResult> ReserveAsync(string reservationId, IReadOnlyDictionary<long, int> items, CancellationToken ct)
    {
        if (await db.Reservations.AnyAsync(r => r.Id == reservationId, ct))
        {
            return ReserveResult.AlreadyReserved();
        }

        var now = clock.GetUtcNow();
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var unavailable = new Dictionary<long, int>();

        // Always lock rows in the same order (by product id) so two orders can never deadlock.
        foreach (var (productId, quantity) in items.OrderBy(i => i.Key))
        {
            var updated = await db.StockItems
                .Where(s => s.ProductId == productId && s.Quantity >= quantity)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.Quantity, x => x.Quantity - quantity)
                    .SetProperty(x => x.UpdatedAt, now), ct);

            if (updated == 0)
            {
                unavailable[productId] = await db.StockItems
                    .Where(s => s.ProductId == productId)
                    .Select(s => (int?)s.Quantity)
                    .FirstOrDefaultAsync(ct) ?? 0;
            }
        }

        if (unavailable.Count > 0)
        {
            await tx.RollbackAsync(ct); // nothing is reserved, not even the available items
            logger.LogInformation("Reservation {ReservationId} rejected: {@Unavailable}", reservationId, unavailable);

            return ReserveResult.Rejected(unavailable);
        }

        db.Reservations.Add(new Reservation
        {
            Id = reservationId,
            Status = ReservationStatus.Reserved,
            CreatedAt = now,
            Items = items.Select(i => new ReservationItem { ReservationId = reservationId, ProductId = i.Key, Quantity = i.Value }).ToList(),
        });

        try
        {
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // The same reservation id arrived twice at the same moment: the other one won.
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();

            return ReserveResult.AlreadyReserved();
        }

        logger.LogInformation("Reservation {ReservationId} accepted ({Count} items)", reservationId, items.Count);

        return ReserveResult.Accepted();
    }

    /// <summary>Give the stock back. Idempotent: releasing twice returns the stock only once.</summary>
    public async Task<ReleaseResult> ReleaseAsync(string reservationId, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // Lock the reservation row: two releases of the same reservation cannot both run.
        await db.Database.ExecuteSqlAsync($"SELECT 1 FROM reservations WHERE id = {reservationId} FOR UPDATE", ct);

        var reservation = await db.Reservations
            .Include(r => r.Items)
            .FirstOrDefaultAsync(r => r.Id == reservationId, ct);

        if (reservation is null)
        {
            return new ReleaseResult(false, "Reservation not found.");
        }

        if (reservation.Status == ReservationStatus.Released)
        {
            return new ReleaseResult(true, "Already released.");
        }

        var now = clock.GetUtcNow();

        foreach (var item in reservation.Items.OrderBy(i => i.ProductId))
        {
            await db.StockItems
                .Where(s => s.ProductId == item.ProductId)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.Quantity, x => x.Quantity + item.Quantity)
                    .SetProperty(x => x.UpdatedAt, now), ct);
        }

        reservation.Status = ReservationStatus.Released;
        reservation.ReleasedAt = now;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        logger.LogInformation("Reservation {ReservationId} released", reservationId);

        return new ReleaseResult(true, "Released.");
    }
}
