# Architecture

```
Flutter (mobile) --REST + WebSocket--> Laravel (core-api) --gRPC--> .NET (inventory-service)
```

- **core-api (Laravel):** auth (Sanctum), products, cart, orders, payments, real-time events (Reverb).
- **inventory-service (.NET gRPC):** stock levels and reservations. Owns its own database.
- **Contract:** `proto/inventory.proto` is the single source of truth between the two services.

## Order flow

1. Client creates an order -> core-api calls `ReserveStock`.
2. Payment succeeds -> `ConfirmReservation`.
3. Payment fails / order cancelled -> `ReleaseReservation`.
