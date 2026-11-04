# Architecture

```
Flutter (mobile) --REST /api/v1--> Laravel (core-api) --gRPC--> .NET (inventory-service)
                                        |                              |
                                      MySQL                       PostgreSQL
```

- **core-api (Laravel):** users & roles (JWT), products, orders, notifications.
- **inventory-service (.NET gRPC):** stock quantities and reservations. Owns its own database.
- **Contract:** `proto/inventory.proto` is the only way the two services talk.

## Contract operations

| RPC | Purpose |
|---|---|
| `GetStock` / `GetStockBatch` | How many units are left |
| `ReserveStock` | Reserve all items of an order in one call (all or nothing) |
| `ReleaseStock` | Give back a reservation when the order fails or is cancelled |
| `SetStock` | Admin inventory management |

## Order flow

1. core-api generates a `reservation_id` (UUID) and calls `ReserveStock` with every item.
2. Rejected -> `409`, the order is **not** created. Inventory down/slow (deadline) -> `503`.
3. Accepted -> the order is saved in a DB transaction.
4. Saving fails -> `ReleaseStock(reservation_id)` returns the stock.

## Race condition

`ReserveStock` decrements with a conditional atomic update
(`quantity = quantity - n WHERE quantity >= n`) inside one transaction,
so when many orders hit the last unit at the same moment only one succeeds.
